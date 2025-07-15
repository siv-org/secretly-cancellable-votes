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

    // Step 5: D2 = invsqrt * u2
    signal D2[3] <== ChunkedMulModP()(invsqrt, u2);

    // Step 6: zInv = D1 * D2 * t
    signal D1D2[3] <== ChunkedMulModP()(D1, D2);
    signal zInv[3] <== ChunkedMulModP()(D1D2, t);

    // Step 7: Check if `t * zInv` is negative
    signal t_zInv[3] <== ChunkedMulModP()(t, zInv);
    signal isNegative_t_zInv <== ChunkedEdIsNegative()(t_zInv);

    // Step 8: Conditional swap based on isNegative_t_zInv
    // If so, we need to swap x and y with sqrt(-1) factors
    // x' = y * sqrt(-1), y' = x * sqrt(-1)
    signal y_sqrt_m1[3] <== ChunkedMulModP()(y, SQRT_M1()());
    signal x_sqrt_m1[3] <== ChunkedMulModP()(x, SQRT_M1()());

    signal mux_x[3] <== Multiplexor2(3)(isNegative_t_zInv, [x, y_sqrt_m1]);
    signal mux_y[3] <== Multiplexor2(3)(isNegative_t_zInv, [y, x_sqrt_m1]);

    signal D1_INVSQRT_A_MINUS_D[3] <== ChunkedMulModP()(D1, INVSQRT_A_MINUS_D()());
    signal D[3] <== Multiplexor2(3)(isNegative_t_zInv, [D2, D1_INVSQRT_A_MINUS_D]);
    // -- Confirmed above matches reference --

    // Step 9: Check if x * zInv is negative
    signal x_zInv[3] <== ChunkedMulModP()(mux_x, zInv);
    signal isNegative_x_zInv <== ChunkedEdIsNegative()(x_zInv);
    signal neg_y[3] <== ChunkedSubModP()(P()(), mux_y);
    signal mux_y2[3] <== Multiplexor2(3)(isNegative_x_zInv, [mux_y, neg_y]);

    // Step 10: Compute s = (z - y) * D
    component sub_z_y_final = ChunkedSub(3, base);
    for (var i = 0; i < 3; i++) {
        sub_z_y_final.a[i] <== z[i];
        sub_z_y_final.b[i] <== mux_y2[i]; // adjusted y
    }

    component mul_s = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        mul_s.in1[i] <== sub_z_y_final.out[i];
        mul_s.in2[i] <== D[i];
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

template INVSQRT_A_MINUS_D() {
    var base = 85;
    var INVSQRT_A_MINUS_D_WHOLE = 54469307008909316920995813868745141605393597292927456921205312896311721017578;
    signal output INVSQRT_A_MINUS_D[3] <== [INVSQRT_A_MINUS_D_WHOLE % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> base) % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> (2 * base)) % (1 << base)];
}

// npx snarkjs r1cs info build/RistrettoToBytes.r1cs
// [INFO]  snarkJS: Curve: bn-128
// [INFO]  snarkJS: # of Wires: 54376
// [INFO]  snarkJS: # of Constraints: 54651
// [INFO]  snarkJS: # of Private Inputs: 12
// [INFO]  snarkJS: # of Public Inputs: 0
// [INFO]  snarkJS: # of Labels: 109976
// [INFO]  snarkJS: # of Outputs: 32