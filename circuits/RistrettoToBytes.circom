pragma circom 2.2.2;

include "bitify.circom";
include "ed25519/chunkedadd.circom";
include "ed25519/ChunkedSub.circom";
include "ed25519/chunkedmul.circom";
include "ChunkedSqrt.circom";
include "./ChunkedModP.circom";

template RistrettoToBytes() {
    // Input: x, y, z, t in chunked form
    signal input P[4][3];
    signal x[3] <== P[0];
    signal y[3] <== P[1];
    signal z[3] <== P[2];
    signal t[3] <== P[3];

    // Output compressed s in bytes
    signal output s_bytes[32];

    var base = 85;

    // Constants for Ristretto encoding, in chunked form
    var INVSQRT_A_MINUS_D_WHOLE = 54469307008909316920995813868745141605393597292927456921205312896311721017578;
    var INVSQRT_A_MINUS_D[3] = [INVSQRT_A_MINUS_D_WHOLE % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> base) % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> (2 * base)) % (1 << base)];

    // Step 1: u1 = mod((z + y) * (z - y))
    signal z_plus_y[3] <== ChunkedAddAndTruncate()(z, y);
    signal z_minus_y[3] <== ChunkedSubModP()(z, y);
    signal u1[3] <== ChunkedMulModP()(z_plus_y, z_minus_y);

    // Step 2: u2 = mod(x * y)
    signal u2[3] <== ChunkedMulModP()(x, y);

    // Step 3: invsqrt = invertSqrt(u1 * u2^2)
    signal u2_sq[3] <== ChunkedMulModP()(u2, u2);
    signal u1_times_u2_sq[3] <== ChunkedMulModP()(u1, u2_sq);
    signal invsqrt[3] <== ChunkedInvertSqrt(3, base)(u1_times_u2_sq);

    // Step 4: D1 = invsqrt * u1
    signal D1[3] <== ChunkedMulModP()(invsqrt, u1);
    // -- Confirmed above matches reference --

    // Step 5: D2 = invsqrt * u2
    component mul_D2 = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_D2.in1[i] <== invsqrt[i];
        mul_D2.in2[i] <== u2[i];
    }

    // Step 6: zInv = D1 * D2 * t
    component mul_zInv_temp = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_zInv_temp.in1[i] <== D1[i];
        mul_zInv_temp.in2[i] <== mul_D2.out[i];
    }

    component mul_zInv = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_zInv.in1[i] <== mul_zInv_temp.out[i];
        mul_zInv.in2[i] <== t[i];
    }

    // Step 7: Check if t * zInv is negative
    component mul_t_zInv = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_t_zInv.in1[i] <== t[i];
        mul_t_zInv.in2[i] <== mul_zInv.out[i];
    }

    component isNegative_t_zInv = IsNegativeChunked(3, base);
    for (var i = 0; i < 3; i++) {
        isNegative_t_zInv.in[i] <== mul_t_zInv.out[i];
    }

    // Step 8: Conditional swap based on t * zInv sign
    // If t * zInv is negative, we need to swap x and y with sqrt(-1) factors
    // x' = y * sqrt(-1), y' = x * sqrt(-1)
    signal mul_x_sqrt_m1[3] <== ChunkedMulModP()(x, SQRT_M1()());
    signal mul_y_sqrt_m1[3] <== ChunkedMulModP()(y, SQRT_M1()());

    component mux_x = Multiplexor2(3);
    component mux_y = Multiplexor2(3);
    mux_x.sel <== isNegative_t_zInv.out;
    mux_y.sel <== isNegative_t_zInv.out;
    for (var i = 0; i < 3; i++) {
        mux_x.in[0][i] <== x[i];
        mux_x.in[1][i] <== mul_y_sqrt_m1[i]; // y * sqrt(-1)
        mux_y.in[0][i] <== y[i];
        mux_y.in[1][i] <== mul_x_sqrt_m1[i]; // x * sqrt(-1)
    }

    // Step 9: Check if x * zInv is negative
    component mul_x_zInv = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_x_zInv.in1[i] <== mux_x.out[i];
        mul_x_zInv.in2[i] <== mul_zInv.out[i];
    }

    component isNegative_x_zInv = IsNegativeChunked(3, base);
    for (var i = 0; i < 3; i++) {
        isNegative_x_zInv.in[i] <== mul_x_zInv.out[i];
    }

    // Step 10: Conditional negation of y based on x * zInv sign
    component neg_y = ChunkedNeg(3, base);
    for (var i = 0; i < 3; i++) {
        neg_y.in[i] <== mux_y.out[i];
    }

    component mux_y_final = Multiplexor2(3);
    mux_y_final.sel <== isNegative_x_zInv.out;
    for (var i = 0; i < 3; i++) {
        mux_y_final.in[0][i] <== mux_y.out[i]; // original y
        mux_y_final.in[1][i] <== neg_y.out[i]; // negated y
    }

    // Step 11: Compute s = (z - y) * D
    component sub_z_y_final = ChunkedSub(3, base);
    for (var i = 0; i < 3; i++) {
        sub_z_y_final.a[i] <== z[i];
        sub_z_y_final.b[i] <== mux_y_final.out[i]; // adjusted y
    }

    // Choose D based on t * zInv sign
    component mul_D1_invsqrt = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_D1_invsqrt.in1[i] <== D1[i];
        mul_D1_invsqrt.in2[i] <== INVSQRT_A_MINUS_D[i];
    }

    component mux_D = Multiplexor2(3);
    mux_D.sel <== isNegative_t_zInv.out;
    for (var i = 0; i < 3; i++) {
        mux_D.in[0][i] <== mul_D2.out[i]; // D2
        mux_D.in[1][i] <== mul_D1_invsqrt.out[i]; // D1 * INVSQRT_A_MINUS_D
    }

    component mul_s = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_s.in1[i] <== sub_z_y_final.out[i];
        mul_s.in2[i] <== mux_D.out[i];
    }

    // Ensure s is positive (if negative, negate it)
    component isNegative_s = IsNegativeChunked(3, base);
    for (var i = 0; i < 3; i++) {
        isNegative_s.in[i] <== mul_s.out[i];
    }

    component neg_s = ChunkedNeg(3, base);
    for (var i = 0; i < 3; i++) {
        neg_s.in[i] <== mul_s.out[i];
    }

    component mux_s_final = Multiplexor2(3);
    mux_s_final.sel <== isNegative_s.out;
    for (var i = 0; i < 3; i++) {
        mux_s_final.in[0][i] <== mul_s.out[i]; // original s
        mux_s_final.in[1][i] <== neg_s.out[i]; // negated s
    }

    // Convert final s to bytes
    component sToBytes = ChunkedToBytes(3, base);
    for (var i = 0; i < 3; i++) {
        sToBytes.in[i] <== mux_s_final.out[i];
    }

    for (var i = 0; i < 32; i++) {
        s_bytes[i] <== sToBytes.out[i];
    }
}

template Multiplexor2(chunks) {
    signal input sel;
    signal input in[2][chunks];
    signal output out[chunks];

    signal notSel;
    notSel <== 1 - sel;

    signal t0[chunks];
    signal t1[chunks];

    for (var i = 0; i < chunks; i++) {
        t0[i] <== in[0][i] * notSel;
        t1[i] <== in[1][i] * sel;
        out[i] <== t0[i] + t1[i];
    }
}

template ChunkedNeg(chunks, base) {
    signal input in[chunks];
    signal output out[chunks];

    var max_val = (1 << base) - 1;
    for (var i = 0; i < chunks; i++) {
        out[i] <== max_val - in[i];
    }
}

template IsNegativeChunked(chunks, base) {
    signal input in[chunks];
    signal output out;

    // Check if the least significant bit of the first chunk is 1
    // This indicates negativity in little-endian representation
    component bits = Num2Bits(base);
    bits.in <== in[0];
    out <== bits.out[0];
}

template ChunkedToBytes(chunks, base) {
    signal input in[chunks];
    signal output out[32];

    var totalbits = chunks * base; // should be 255

    assert(totalbits == 255); // sanity check

    component bits = Num2Bits(255);

    // Flatten
    signal acc[chunks + 1];
    acc[0] <== 0;
    for (var i = 0; i < chunks; i++) {
        acc[i+1] <== acc[i] + in[i] * (1 << (i * base));
    }
    bits.in <== acc[chunks];

    // Pack first 31 full bytes
    signal byte_acc[32][9];
    for (var j = 0; j < 31; j++) {
        byte_acc[j][0] <== 0;
        for (var k = 0; k < 8; k++) {
            byte_acc[j][k+1] <== byte_acc[j][k] + bits.out[j*8 + k] * (1 << k);
        }
        out[j] <== byte_acc[j][8];
    }

    // Last byte only has 7 bits
    byte_acc[31][0] <== 0;
    for (var k = 0; k < 7; k++) {
        byte_acc[31][k+1] <== byte_acc[31][k] + bits.out[31*8 + k] * (1 << k);
    }
    out[31] <== byte_acc[31][7];
}

template P() {
    signal output out[3] <== [(2 ** 85 - 19), (2 ** 85 - 1), (2 ** 85 - 1)];
}

template SQRT_M1() {
    // √(-1) aka √(a) aka 2^((p-1)/4)
    signal output out[3] <== [ 19212814651911893326667952, 5789323763396775551972713, 13150778395323338825847616 ];
}

// npx snarkjs r1cs info build/RistrettoToBytes.r1cs
// [INFO]  snarkJS: Curve: bn-128
// [INFO]  snarkJS: # of Wires: 54376
// [INFO]  snarkJS: # of Constraints: 54651
// [INFO]  snarkJS: # of Private Inputs: 12
// [INFO]  snarkJS: # of Public Inputs: 0
// [INFO]  snarkJS: # of Labels: 109976
// [INFO]  snarkJS: # of Outputs: 32