import CacheTypes;

// Address Helper Functions
// NOTE: Each of these functions can be implemented with a single line.
// Use the constants logCacheSets and logWordsPerLine, defined in CacheTypes.ms
////////////////////////////////////////

// Extract the Cache Line Index from a given memory address
function CacheIndex getIndex(Word byteAddress);
    return byteAddress[logCacheSets+logWordsPerLine+1:logWordsPerLine+2]; //TODO Your code here
endfunction

// Extract the Cache Line Tag from a given memory address
function CacheTag getTag(Word byteAddress);
    return byteAddress[31:logCacheSets+logWordsPerLine+2]; //TODO Your code here
endfunction

// Extract the Cache Line Word Offset from a given memory address
function WordOffset getWordOffset(Word byteAddress);
    return byteAddress[logWordsPerLine+1:2]; //TODO Your code here
endfunction

//Extract the line address (tag + index) from a given memory address
function LineAddr getLineAddr(Word byteAddress);
    return byteAddress[31:logWordsPerLine+2]; //TODO Your code here
endfunction
