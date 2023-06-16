// Don't change signature of existing functions. You may write additional helper functions if you want.


// Description: 32-bit right barrel shifter
// Arguments: in (value to be shifted); sftSz (shift size); sft_in (the bit shifted in)
// Return: {sft_in's, in[31:sftSz]}
function Bit#(32) barrelRShift(Bit#(32) in, Bit#(5) sftSz, Bit#(1) sft_in);
    Bit#(32) r4 = (sftSz[4] == 0) ? in : signExtend({sft_in, in[31:16]});
    Bit#(32) r3 = (sftSz[3] == 0) ? r4 : signExtend({sft_in, r4[31:8]});
    Bit#(32) r2 = (sftSz[2] == 0) ? r3 : signExtend({sft_in, r3[31:4]});
    Bit#(32) r1 = (sftSz[1] == 0) ? r2 : signExtend({sft_in, r2[31:2]});
    Bit#(32) r0 = (sftSz[0] == 0) ? r1 : signExtend({sft_in, r1[31:1]});
    return r0;
endfunction

// Description: 32-bit arithmetic/logic right shifter
// Arguments: in (value to be shifted); sftSz (shift size); arith (1 = arithmetic, 0 = logic)
// Return: in >> sftSz
function Bit#(32) sr32(Bit#(32) in, Bit#(5) sftSz, Bit#(1) arith);
    Bit#(1) sft_in = 0;
    if (arith == 1) sft_in = in[31];
    Bit #(32) ret = barrelRShift(in, sftSz, sft_in);
    return ret;
endfunction


// Description: 32-bit logic left shifter
// Arguments: in (values to be shifted); sftSz (shift size)
// Return: a << b
function Bit#(32) sll32(Bit#(32) in, Bit#(5) sftSz);
    Bit #(32) ret = barrelRShift(reverseBits(in), sftSz, 0);
    return reverseBits(ret);
endfunction


// Description: 32-bit FULL shifter
// Arguments: in (value to be shifted); sftSz (shift size);
// ShiftTypes:
// LogicalRightShift
// ArithmeticRightShift
// LeftShift
//
// Return: in >> sftSz when right shift; in << sftSz otherwise
typedef enum {LogicalRightShift, ArithmeticRightShift, LeftShift} ShiftType;

function Bit#(32) sft32(Bit#(32) in, Bit#(5) sftSz, ShiftType shiftType);
    Bit#(32) ret = in;
    Bit#(1) sft_in = 0;
    if(shiftType == ArithmeticRightShift) sft_in = in[31];
    else if(shiftType == LeftShift) ret = reverseBits(in);
    ret = barrelRShift(ret, sftSz, sft_in);
    if(shiftType == LeftShift) ret = reverseBits(ret);
    return ret;
endfunction 



// Description: one-bit less-than comparator
// Arguments: a, b (1-bit values), eq, lt (eq and lt from previous comparator)
// Return: {eq_i, lt_i}
function Bit#(2) cmp(Bit#(1) a, Bit#(1) b, Bit#(1) eq, Bit#(1) lt);
    Bit#(2) ab = {a, b};
    Bit#(2) ret = 2'b00;
    if ((ab == 2'b00 || ab == 2'b11) && eq == 1 && lt == 0 ) ret = 2'b10;
    else if (lt == 1) ret = 2'b01;
    else if ((ab == 2'b01) && eq == 1 && lt == 0 ) ret = 2'b01;
    else if ((ab == 2'b10) && eq == 1 && lt == 0) ret = 2'b00;
    return ret;
endfunction

// Description: unsigned 32-bit less-than comparator
// Arguments: a, b unsigned 32-bit values
// Return: 1 if a < b
function Bit#(1) ltu32(Bit#(32) a, Bit#(32) b);
   Bit#(2) ret = 0;
   Bit#(1) eq = 1;
   Bit#(1) lt = 0;
   for (Integer i = 31 ; i >= 0; i = i - 1) begin
        ret = cmp(a[i], b[i], eq, lt);
        eq = ret[1];
        lt = ret[0];
    end
    return lt;
endfunction

// Description: Signed/Unsigned 32-bit less-than comparator
// Arguments: a b (32-bit values); isSigned (signed comparator when 1, unsigned otherwise)
// Return: 1 if a < b
function Bit#(1) lt32(Bit#(32) a, Bit#(32) b, Bit#(1) isSigned);
    Bit#(1) ret = 0;
    if (isSigned == 1) begin
        a = {~a[31], a[30: 0]};
        b = {~b[31], b[30: 0]};
    end
    ret = ltu32(a, b);
    return ret;
endfunction

// Description: one-bit full adder
// Arguments: a, b, carry in
// Return: {carry out, sum}
function Bit#(2) fullAdder(Bit#(1) a, Bit#(1) b, Bit#(1) carryIn);
    let cout = (a & b) | (a & carryIn) | (b & carryIn);
    let sum = a ^ b ^ carryIn;
    return {cout, sum};
endfunction

// Description: n-bit ripple-carry adder with a carry-in
// Arguments: a, b, carryIn
// Return: sum of a, b, and carryIn
function Bit#(n) rca#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) carryIn);
    Bit#(2) res = 2'b00;
    Bit#(n) ret = 0;
    for (Integer i = 0 ; i < n; i = i + 1) begin
        res = fullAdder(a[i], b[i], carryIn);
        carryIn = res[1];
        ret[i] = res[0];
    end
    return ret;
endfunction

// Description: n-bit ripple-carry adder/subractor
// Arguments: a, b (n-bit operands); isSub (1 => subtract, 0 => add)
// Return: isSub == 0 ? a + b : a - b
function Bit#(n) addSub#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) isSub);
    Bit#(n) ret = 0;
    Bit#(1) carry = 0;
    if (isSub == 1) b = ~b;
    if (isSub == 1) carry = 1;

    ret = fastAdd#(n)(a, b, carry);
    return ret;
endfunction


// Alu Functions:
// Add: 32-bit Addition         (a + b)
// Sub: 32-bit Subtraction      (a - b)
// And: 32-bit Bitwise And      (a & b)
// Or: 32-bit Bitwise Or        (a | b)
// Xor: 32-bit Bitwise Xor      (a ^ b)
// Slt: Set less than           (a <u b ? 1 : 0)
// Sltu: Set less than unsigned (a <s b ? 1:0)
// Sll: Left logic shfit        (a << b)
// Srl: Right logic shift       (a >>u b)
// Sra: Right arithmetic shift  (a >>s b)
typedef enum {Add, Sub, And, Or, Xor, Slt, Sltu, Sll, Srl, Sra} AluFunc;

// Description: Arithmetic Logic Unit (ALU)
// Arguments: a, operand a; b, operand b; func, ALU operation
// Return: output of ALU
function Bit#(32) alu(Bit#(32) a, Bit#(32) b, AluFunc func);
    Bit#(1) bol = 0;
    Bit#(32) ret = 0;
    if (func == Add || func == Sub) begin
        if (func == Sub) bol = 1;
        ret = addSub#(32)(a, b, bol);
    end

    if (func == And) ret = a & b;
    if (func == Or) ret = a | b;
    if (func == Xor) ret = a ^ b;

    if(func == Slt || func == Sltu) begin
        if (func == Slt) bol = 1;
        ret = zeroExtend(lt32(a, b, bol));
    end

    if(func == Sll || func == Srl || func == Sra) begin
        Bit#(5) b1 = b[4:0];
        ShiftType f = ArithmeticRightShift;
        if (func == Sll) f = LeftShift;
        else if (func == Srl) f = LogicalRightShift;
        ret = sft32(a, b1, f);
    end
    return ret;
endfunction


// Description: Alternative shifter implementation (Discussion Question)
function Bit#(32) sft32_alt(Bit#(32) in, Bit#(5) sftSz, ShiftType shiftType);
    return (shiftType == LeftShift) ? sft32(in, sftSz, LeftShift) : ((shiftType == ArithmeticRightShift)? sft32(in, sftSz, ArithmeticRightShift) : sft32(in, sftSz, LogicalRightShift));
endfunction


// Description: N-bit fast adder with a carry-in (Design Exercise)
// Arguments: a, b, carryIn
// Return: sum of a, b, and carryIn
function Bit#(n) fastAdd#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) carryIn);
    Bit#(n) ret = 0;
    Bit#(n) c = 0;
    Bit#(n) g = 0; // produced g's of all (a, b) green boxes, g_i saved in g[i]
    Bit#(n) p = 0; // produced p's of all (a, b) green boxes,

    // get {p, g} from all indexs, saved in g and p
    for (Integer i = n-1 ; i >= 0; i = i - 1) begin
        g[i] = a[i] & b[i];
        p[i] = a[i] | b[i];
    end

    // gray boxes, log(n) layers
    for (Integer j = 1 ; j <= n/2; j = j*2) begin
        for (Integer i = n-1 ; i >= j; i = i - 1) begin
            g[i] = g[i] | (p[i] & g[i-j]);
            p[i] = p[i] & p[i-j];
        end
    end
     
    // c level, compute with carryIn
    for (Integer i = n-2 ; i >= 0; i = i - 1) begin
        c[i+1] = g[i] | (p[i] & carryIn);
    end

    c[0] = carryIn;
    // get result
    for (Integer i = n-1 ; i >= 0; i = i - 1) begin
        ret[i] = a[i] ^ b[i] ^ c[i];
    end

    return ret;
endfunction
