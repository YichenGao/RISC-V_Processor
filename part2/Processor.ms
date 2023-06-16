import ProcTypes;

import RegisterFile;
import Decode;
import Execute;

// MainMemory includes the MainMemory port
// and the SingleCycleMemory modules
import MainMemory;

// Milestone 2: Select which cache(s) to import
import DirectMappedCache;
//import TwoWayCache;

// Types associated with the fetch stage
typedef enum {
    Dequeue, // Consume instruction at the f2d output, if any
    Stall, // Do not consume instruction at f2d
    Redirect  // Redirect fetch to another PC, annulling any fetched instructions
} FetchAction;

typedef struct {
    FetchAction fetchAction;
    Word redirectPC;  // PC to fetch from, used only if fetchAction is Redirect
} FetchInput;


typedef struct {
    Word pc;
    Word inst;
} F2D;

typedef struct {
    Word pc;
    DecodedInst dInst;
    Word rVal1;
    Word rVal2;
    // Add anything you need
} D2E;

typedef struct {
    Word pc;
    IType iType;
    Maybe#(RIndx) dst;
    Word data;
    // Add anything you need
} E2W;


// Fetch stage, including pc and instruction memory/cache
// 
// See handout for the structure of the recommended fetch stage. You can test
// this module using FetchTB (ms sim FetchTB.ms FetchTB).
//
// Implementing this module is optional: you can place the fetch logic and
// iMem/iCache inside the processor instead. We recommend you use a separate
// module at least during Part 2 to ease debugging.
module Fetch;
    Reg#(Word) pc(0);
    Reg#(Bool) ready(True);

    // Single-cycle Instruction Memory
    // Milestone 2: comment this declaration out
    //SingleCycleMemory iMem;
    
    // Line-based Main Memory to use with caches
    // Milestone 2: uncomment this declaration
    MainMemory iMem;

    // Milestone 2: choose which type of iCache to use
    DirectMappedCache iCache(iMem);
    //TwoWayCache iCache(iMem);

    input FetchInput in;

    // Milestone 2: Modify to use iCache instead
    method Maybe#(F2D) f2d; 
        if (ready) begin
            return isValid(iCache.data)?
            Valid(F2D{pc: pc, inst: fromMaybe(?, iCache.data)}) : Invalid;
        end else begin
            return Invalid;
        end
    endmethod
    
    rule fetch;
        // Fetch instructions from iMem/iCache and update PC according to in.
        //////////////////////////
        // TODO: Your code here //
        //////////////////////////    
        let fetchAction = in.fetchAction;
        let redirectPC = in.redirectPC;
        let nextpc = pc;

        if (iCache.reqEnabled)  begin
            if (fetchAction == Dequeue) begin
                nextpc = pc + 4;
            end else if (fetchAction == Redirect) begin
                nextpc = redirectPC;
            end
            pc <= nextpc;
            iCache.req = Valid(MemReq{op: Ld, addr: nextpc, data: ?}); 
            ready <= True;
        end else begin
            if (fetchAction == Dequeue) begin
                nextpc = pc + 4;
                pc <= nextpc;
            end else if (fetchAction == Redirect) begin
                nextpc = redirectPC;
                ready <= False;
                pc <= nextpc;
            end
        end


    endrule

    // Used only for pipeline debugging; you should not use this method
    // elsewhere in your code (assume the fetch stage can run ahead)
    method Word getPc = pc; 
endmodule


module Processor;
    Fetch fetch;

    RegisterFile rf;

    // Single-cycle data memory
    // Milestone 2: comment this declaration out
    //SingleCycleMemory dMem;

    // Line-based Main Memory to use with caches
    // Milestone 2: uncomment this declaration
    MainMemory dMem;

    // Milestone 2: choose which type of data cache to use
    // NOTE: The CacheWrapper#() type of the dCache is critical, as it is used
    // for detecting that the program has finished running
    CacheWrapper#(DirectMappedCache) dCache(dMem);
    //CacheWrapper#(TwoWayCache) dCache(dMem);

    // Pipeline Registers
    Reg#(Maybe#(D2E)) d2e(Invalid);
    Reg#(Maybe#(E2W)) e2w(Invalid);

    // Performance counters
    // These are used in the processor rule for debugging help, by tracking the
    // cycles and instructions completed. They are not needed for correctness
    // and you may remove them, but doing so is unlikely to reduce cycle time.
    Reg#(Bit#(32)) cycle(0);
    Reg#(Bit#(32)) instrs(0);

    rule tick;
        //////////////////////
        // Debugging Helper //
        //////////////////////
        cycle <= cycle + 1;
        // Uncomment the code below to print pipeline state each cycle
        /*begin
            $write("[%d] F|D|E|W PCs: ", cycle);
            $write("%x|", fetch.getPc);
            if (isValid(fetch.f2d)) $write("%x|", fromMaybe(?, fetch.f2d).pc); else $write("%8s|", "NOP");
            if (isValid(d2e)) $write("%x|", fromMaybe(?, d2e).pc); else $write("%8s|", "NOP");
            if (isValid(e2w)) $write("%x", fromMaybe(?, e2w).pc); else $write("%8s", "NOP");
            $display("  instrs: %d", instrs);
        end*/

        /////////////////////
        // Writeback Stage //
        /////////////////////
        // Signals used by decode to handle data hazards
        RIndx dstW = 0;
        Word dataW = ?;

        // Milestone 2:
        // Signal for dCache-induced stalls
        Bool dStall = False;

        if (isValid(e2w)) begin
            let e2w_v = fromMaybe(?, e2w);

            //////////////////////////
            // TODO: Your code here //
            //////////////////////////
            let data = e2w_v.data;
            if (e2w_v.iType == LOAD) begin
                if (isValid(dCache.data)) begin
                    data = fromMaybe(?, dCache.data);
                end else begin
                    dStall = True;
                end
            end

            if (isValid(e2w_v.dst)) begin
                rf.wr = Valid(RegWriteArgs{index: fromMaybe(?,e2w_v.dst), data: data});
                dstW = fromMaybe(0,e2w_v.dst); // check for STALL signal
                dataW = data;
            end
            // Count every instruction that leaves the writeback stage
            // (for debugging help)
            instrs <= instrs + 1;

            // BEGIN: DO NOT REMOVE OR MODIFY THIS CODE
            // If unsupported instruction, stops simulation and print the state of the processor
            if (e2w_v.iType == Unsupported) begin
                $display("Reached unsupported instruction");
                $display("Dumping the state of the processor");
                $display("pc = 0x%x", e2w_v.pc);
                $display(rf.fshow);
                $display("Quitting simulation.");
                $finish;
            end
            // END: DO NOT REMOVE OR MODIFY THIS CODE
        end

        ///////////////////
        // Execute Stage //
        ///////////////////
        // Signals used to handle mispredictions
        Bool annul = False;
        Word redirectPC = ?;

        // Signals used by decode to handle data hazards
        RIndx dstE = 0;
        Word dataE = ?;

        if (!dStall && isValid(d2e)) begin
            let d2e_v = fromMaybe(?, d2e);

            //////////////////////////
            // TODO: Your code here //
            //////////////////////////

            dstE = fromMaybe(0,d2e_v.dInst.dst); // for STALL signal

            ExecInst eInst = execute(d2e_v.dInst, d2e_v.rVal1, d2e_v.rVal2, d2e_v.pc);
            let dst = eInst.dst;
            let addr = eInst.addr;
            let tp = eInst.iType;
            let data = eInst.data;
            if (tp == LOAD)  begin
                if (dCache.reqEnabled) begin
                    dCache.req = Valid(MemReq{op: Ld, addr: addr, data: ?}); 
                end else begin
                    dStall = True;
                end 

            end else if (tp == STORE) begin
                if (dCache.reqEnabled) begin
                    dCache.req = Valid(MemReq{op: St, addr: addr, data: data}); 
                end else begin
                    dStall = True;
                end 
            end
            
            if (!dStall) e2w <= Valid(E2W{pc: d2e_v.pc, iType: tp, dst: dst, data: data});
            else e2w <= Invalid;

            if (d2e_v.pc + 4 != eInst.nextPc) begin // check if branch
                annul = True;
                redirectPC = eInst.nextPc;
            end 
        end else if (!dStall) begin
            e2w <= Invalid;
        end 

        //////////////////
        // Decode Stage //
        //////////////////
        // Signal for decode stalls
        Bool stall = False;

        if (annul) begin
            if(!dStall) begin
                d2e <= Invalid;
            end            
            fetch.in = FetchInput{fetchAction: Redirect, redirectPC: redirectPC};
        end else if(!dStall && !annul && isValid(fetch.f2d)) begin
            let f2d_v = fromMaybe(?, fetch.f2d);
            let inst = fromMaybe(?, fetch.f2d).inst;
            let myPc = fromMaybe(?, fetch.f2d).pc;
            DecodedInst dInst = decode(inst);
            Word rVal1 = rf.rd1(dInst.src1);
            Word rVal2 = rf.rd2(dInst.src2);

            if (((dstW == 0) || (dstW != dInst.src1 && dstW != dInst.src2)) &&
            ((dstE == 0) || (dstE != dInst.src1 && dstE != dInst.src2))) begin
                fetch.in = FetchInput{fetchAction: Dequeue, redirectPC: ?};
                d2e <= Valid(D2E{pc: myPc, dInst: dInst, rVal1: rVal1, rVal2: rVal2});
            end else begin
                Bool valid1 = False;
                if (dstW == dInst.src1) begin
                    rVal1 = dataW;
                    valid1 = True;
                end else if (dstW != dInst.src1 && dstE != dInst.src1) begin
                    valid1 = True;
                end

                Bool valid2 = False;
                if (dstW == dInst.src2) begin
                    rVal2 = dataW;
                    valid2 = True;
                end else if (dstW != dInst.src2 && dstE != dInst.src2) begin
                    valid2 = True;
                end

                if (valid1 && valid2) begin
                    fetch.in = FetchInput{fetchAction: Dequeue, redirectPC: ?};
                    d2e <= Valid(D2E{pc: myPc, dInst: dInst, rVal1: rVal1, rVal2: rVal2});
                end else begin
                    d2e <= Invalid;
                    fetch.in = FetchInput{fetchAction: Stall, redirectPC: ?};
                end
            end
        end else begin
            if(!dStall) begin
                d2e <= Invalid;
            end
            fetch.in = FetchInput{fetchAction: Stall, redirectPC: ?};
        end
        ///////////////////////
        // Drive fetch stage //
        ///////////////////////

        // TODO: Change to implement correct stall/annul behavior. You may find
        // it easier to set fetch.in from the decode stage.
        
    endrule

    // This method gives a non-trivial output that depends on execution so that
    // synth doesn't optimize out the whole processor :)
    method Word getPc = fetch.getPc;
endmodule
