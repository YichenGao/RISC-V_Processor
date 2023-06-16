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

// TODO: Complete the implementation of TwoWayCache
// NOTE: Implementing this module requires about 20 new lines of code from DirectMappedCache
module TwoWayCache(MainMemory mainMem);
    // SRAM arrays, one element per way (e.g., dataArrays[0] is the data array of way 0).
    Vector#(2, SRAM#(logCacheSets, Line)) dataArrays;
    Vector#(2, SRAM#(logCacheSets, CacheTag)) tagArrays;
    Vector#(2, SRAM#(logCacheSets, CacheStatus)) statusArrays;

    // LRU bits, one per set. We implement it as registers instead of an SRAM
    // array, because with small caches this is just a few bits (e.g., 64), and
    // SRAMs make sense only for larger memories. This also makes the code
    // simpler, and will make the cache easier to pipeline in the future.
    Vector#(cacheSets, RegU#(Bit#(1))) lru;

    // Registers for holding the current state of the cache and how far along
    // it is in processing a request.
    RegU#(MemReq) curReq;
    Reg#(ReqStatus) state(Ready);
 
    // Hit/miss counters
    Reg#(Word) hits(0);
    Reg#(Word) misses(0);
    
    input Maybe#(MemReq) req default = Invalid;
    
    // TODO return True if the cache can accept a new request
    method Bool reqEnabled = (state == Ready);

    // TODO return True if the cache is in lookup and it is a hit in this way.
    function Bool isHit(Integer way);
        let res;
        if (state == Lookup) begin
            let tag = fromMaybe(?, tagArrays[way].data);
            let st = fromMaybe(?, statusArrays[way].data);
            if (getTag(curReq.addr) == tag && ( st != NotValid)) res = True;
            else res = False;
        end else res = False;
        return res;
    endfunction

    rule tick;
        if (state == Ready && isValid(req)) begin
            let index = getIndex(fromMaybe(?, req).addr);
            tagArrays[0].req = Valid(TagReq{addr: index, write: False, data:  ?});
            dataArrays[0].req = Valid(DataReq{addr: index, write: False, data:  ?});
            statusArrays[0].req = Valid(StatusReq{addr: index, write: False, data:  ?});
            tagArrays[1].req = Valid(TagReq{addr: index, write: False, data:  ?});
            dataArrays[1].req = Valid(DataReq{addr: index, write: False, data:  ?});
            statusArrays[1].req = Valid(StatusReq{addr: index, write: False, data:  ?});
            state <= Lookup;
            curReq <= fromMaybe(?, req);
        end else if (state == Lookup) begin
            let index = getIndex(curReq.addr);
            if (isHit(0)) begin // hit at way 0
                if (curReq.op == St) begin
                    let ar = fromMaybe(?, dataArrays[0].data);
                    ar[getWordOffset(curReq.addr)] = curReq.data;
                    dataArrays[0].req = Valid(DataReq{addr: index, write: True, data: ar});
                    statusArrays[0].req = Valid(StatusReq{addr: index, write: True, data: Dirty});
                end
                hits <= hits + 1;
                state <= Ready;
                lru[index] <= 1;
            end else if (isHit(1)) begin // hit at way 1
                if (curReq.op == St) begin
                    let ar = fromMaybe(?, dataArrays[1].data);
                    ar[getWordOffset(curReq.addr)] = curReq.data;
                    dataArrays[1].req = Valid(DataReq{addr: index, write: True, data: ar});
                    statusArrays[1].req = Valid(StatusReq{addr: index, write: True, data: Dirty});
                end
                hits <= hits + 1;
                state <= Ready;
                lru[index] <= 0;
            end else begin
                let way = lru[index];
                let st = fromMaybe(?, statusArrays[way].data);
                if (st != Dirty) begin // clean miss
                    mainMem.req = Valid(LineReq{op: Ld, lineAddr: getLineAddr(curReq.addr), data: ?}); // request data from memory
                    state <= Fill;
                end else begin // dirty miss
                    let tag = fromMaybe(?, tagArrays[way].data);
                    let addr = {tag, getIndex(curReq.addr)};
                    let ar = fromMaybe(?, dataArrays[way].data);
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
            let way = lru[index];
            let ar = fromMaybe(?, mainMem.data);
            if (curReq.op == St) begin // store 
                ar[getWordOffset(curReq.addr)] = curReq.data;
                statusArrays[way].req = Valid(StatusReq{addr: index, write: True, data: Dirty});
            end else begin // load
                statusArrays[way].req = Valid(StatusReq{addr: index, write: True, data: Clean});
            end
            dataArrays[way].req = Valid(DataReq{addr: index, write: True, data: ar});
            tagArrays[way].req = Valid(TagReq{addr: index, write: True, data: getTag(curReq.addr)});
            lru[index] <= ~way;
            state <= Ready;
        end
            
    endrule

    method Maybe#(Word) data;
        // This method should return a Valid output in only two cases:
        // 1. On a load hit (we're in the Lookup state, there's a hit, and
        //    curReq.op == Ld).
        // 2. On a fill for a load request (we're in the Fill state,
        //    mainMem.data is valid, and curReq.op == Ld).
        // In all other cases, the output should be Invalid
        //
        // NOTE: You should be checking the above conditions explicitly in
        //    THIS method so you can return data as soon as possible.
        //    DO NOT place your output into a register in the rule and then
        //    simply return that register here.

        // This function should take about 5-20 lines of code to implement.
        // TODO Your code here
        WordOffset offset = getWordOffset(curReq.addr);
        if (isHit(0) && curReq.op == Ld) return Valid(fromMaybe(?, dataArrays[0].data)[offset]);
        else if (isHit(1) && curReq.op == Ld) return Valid(fromMaybe(?, dataArrays[1].data)[offset]);
        else if (state == Fill && curReq.op == Ld && isValid(mainMem.data)) return Valid(fromMaybe(?, mainMem.data)[offset]);
        else return Invalid;
    endmethod

    method Bit#(32) getHits = hits;
    method Bit#(32) getMisses = misses;
endmodule
