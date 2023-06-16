import CacheTypes;
import CacheHelpers;
import MainMemory;

// ReqStatus (defined in CacheTypes.ms) is used to keep track of the state of the current request
//typedef enum {
//    Ready,         // The cache is ready for a new request
//    Lookup,        // Issued a lookup to tag/data arrays
//    Writeback,     // In main memory access for dirty writeback
//    Fill           // In main memory access for requested data
//} ReqStatus;
//
// Possible flows:
//   HIT: Ready -> Lookup -> Ready
//   MISS, line is clean: Ready -> Lookup -> Fill
//   MISS, line is dirty: Ready -> Lookup -> Writeback -> Fill

// Cache SRAM Synonyms (defined in CacheTypes.ms)
// You may find the following type synonyms helpful to access the tag/data/status arrays
// typedef SRAMReq#(logCacheSets, CacheTag) TagReq;
// typedef SRAMReq#(logCacheSets, Line) DataReq;
// typedef SRAMReq#(logCacheSets, CacheStatus) StatusReq;

// TODO: Complete the implementation of DirectMappedCache
// NOTE: Implementing this module requires about 50 lines of additional code
// (~40 lines in rule tick, ~5-10 lines in method data, 1 line in method reqEnabled, 1 line in function isHit)
module DirectMappedCache(MainMemory mainMem);
    // SRAM arrays. Note that, for a direct-mapped cache,
    // number of cache sets == number of cache lines
    SRAM#(logCacheSets, Line) dataArray;
    SRAM#(logCacheSets, CacheTag) tagArray;
    SRAM#(logCacheSets, CacheStatus) statusArray;
    
    // Registers for holding the current state of the cache and how far along
    // it is in processing a request.
    RegU#(MemReq) curReq;
    Reg#(ReqStatus) state(Ready);
    
    // Hit/miss counters
    Reg#(Word) hits(0);
    Reg#(Word) misses(0);

    input Maybe#(MemReq) req default = Invalid;
    
    // TODO return True if the cache can accept a new request
    method Bool reqEnabled = (state == Ready) || (state == Lookup && curReq.op == Ld && isHit);

    // TODO return True if the cache is in lookup and it is a hit
    function Bool isHit;
        let res;
        if (state == Lookup) begin
            let tag = fromMaybe(?, tagArray.data);
            let st = fromMaybe(?, statusArray.data);
            if (getTag(curReq.addr) == tag && ( st != NotValid)) res = True;
            else res = False;
        end else res = False;
        return res;
    endfunction

    rule tick;
        if (state == Ready && isValid(req)) begin
            let index = getIndex(fromMaybe(?, req).addr);
            tagArray.req = Valid(TagReq{addr: index, write: False, data:  ?});
            dataArray.req = Valid(DataReq{addr: index, write: False, data:  ?});
            statusArray.req = Valid(StatusReq{addr: index, write: False, data:  ?});
            state <= Lookup;
            curReq <= fromMaybe(?, req);
        end else if (state == Lookup) begin
            let index = getIndex(curReq.addr);
            if (isHit()) begin // hit
                if (curReq.op == St) begin
                    let ar = fromMaybe(?, dataArray.data);
                    ar[getWordOffset(curReq.addr)] = curReq.data;
                    dataArray.req = Valid(DataReq{addr: index, write: True, data: ar});
                    statusArray.req = Valid(StatusReq{addr: index, write: True, data: Dirty});
                    state <= Ready;
                end else begin
                    if (isValid(req)) begin
                        let index = getIndex(fromMaybe(?, req).addr);
                        tagArray.req = Valid(TagReq{addr: index, write: False, data:  ?});
                        dataArray.req = Valid(DataReq{addr: index, write: False, data:  ?});
                        statusArray.req = Valid(StatusReq{addr: index, write: False, data:  ?});
                        state <= Lookup;
                        curReq <= fromMaybe(?, req);
                    end else state <= Ready;
                end 
                hits <= hits + 1;
            end else begin
                let st = fromMaybe(?, statusArray.data);
                if (st != Dirty) begin // clean miss
                    mainMem.req = Valid(LineReq{op: Ld, lineAddr: getLineAddr(curReq.addr), data: ?}); // request data from memory
                    state <= Fill;
                end else begin // dirty miss
                    let tag = fromMaybe(?, tagArray.data);
                    let addr = {tag, getIndex(curReq.addr)};
                    let ar = fromMaybe(?, dataArray.data);
                    mainMem.req = Valid(LineReq{op: St, lineAddr: addr, data: ar}); // write to emmory
                    state <= Writeback;
                end
                misses <= misses + 1;
            end 
        end else if (state == Writeback && mainMem.reqEnabled) begin
            mainMem.req = Valid(LineReq{op: Ld, lineAddr: getLineAddr(curReq.addr), data: ?}); // request data from memory
            state <= Fill;
        end else if (state == Fill && isValid(mainMem.data)) begin
            let index = getIndex(curReq.addr);
            let ar = fromMaybe(?, mainMem.data);
            if (curReq.op == St) begin // store 
                ar[getWordOffset(curReq.addr)] = curReq.data;
                statusArray.req = Valid(StatusReq{addr: index, write: True, data: Dirty});
            end else begin // load
                statusArray.req = Valid(StatusReq{addr: index, write: True, data: Clean});
            end
            dataArray.req = Valid(DataReq{addr: index, write: True, data: ar});
            tagArray.req = Valid(TagReq{addr: index, write: True, data: getTag(curReq.addr)});
            state <= Ready;
        end
    endrule

    method Maybe#(Word) data;
        // This method should return a Valid output in only two cases:
        // 1. On a load hit (it is a hit, and curReq.op == Ld).
        // 2. On a fill for a load request (we're in the Fill state,
        //    mainMem.data is valid, and curReq.op == Ld).
        // In all other cases, the output should be Invalid
        //
        // NOTE: You should be checking the above conditions explicitly in
        //    THIS method so you can return data as soon as possible.
        //    DO NOT place your output into a register in the rule and then
        //    simply return that register here.

        // This function should take about 4-8 lines of code to implement.
        // 1. On a load hit (it is a hit, and curReq.op == Ld).
        WordOffset offset = getWordOffset(curReq.addr);
        if (isHit() && curReq.op == Ld) return Valid(fromMaybe(?, dataArray.data)[offset]);
        else if (state == Fill && curReq.op == Ld && isValid(mainMem.data)) return Valid(fromMaybe(?, mainMem.data)[offset]);
        else return Invalid;
    endmethod

    method Bit#(32) getHits = hits;
    method Bit#(32) getMisses = misses;
endmodule
