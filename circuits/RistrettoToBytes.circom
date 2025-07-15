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

    // Step 9: Check if x * zInv is negative
    signal x_zInv[3] <== ChunkedMulModP()(mux_x, zInv);
    signal isNegative_x_zInv <== ChunkedEdIsNegative()(x_zInv);
    signal neg_y[3] <== ChunkedNeg()(mux_y);
    signal mux_y2[3] <== Multiplexor2(3)(isNegative_x_zInv, [mux_y, neg_y]);

    // Step 10: Compute s = (z - y) * D
    signal z_minus_mux_y2[3] <== ChunkedSubModP()(z, mux_y2);
    signal s_1[3] <== ChunkedMulModP()(z_minus_mux_y2, D);
    // Ensure s is positive (if negative, negate it)
    signal neg_s[3] <== ChunkedNeg()(s_1);
    signal isNegative_s <== ChunkedEdIsNegative()(s_1);
    signal s[3] <== Multiplexor2(3)(isNegative_s, [s_1, neg_s]);
    // -- Confirmed above matches reference --

    // Step 11: Convert final `s`, compressed to bytes
    signal output s_bytes[32] <== ChunkedToBytes()(s);
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

template ChunkedNeg() {
    // Calc `-x % p`
    var n = 3;
    signal input x[n];
    signal output out[n] <== ChunkedSubModP()(P()(), x);
}

template ChunkedToBytes() {
    var chunks = 3;
    var base = 85;
    signal input in[chunks];
    signal output out[32];

    assert(chunks * base == 255); // sanity check

    // Convert each chunk to bits
    signal bits_chunk0[85] <== Num2Bits(85)(in[0]);
    signal bits_chunk1[85] <== Num2Bits(85)(in[1]);
    signal bits_chunk2[85] <== Num2Bits(85)(in[2]);

    // Combine all bits into a single array
    signal bits[255];
    for (var i = 0; i < 85; i++) {
        bits[i] <== bits_chunk0[i];
        bits[i + 85] <== bits_chunk1[i];
        bits[i + 170] <== bits_chunk2[i];
    }

    // Pack first 31 full bytes
    signal byte_acc[32][9];
    for (var j = 0; j < 31; j++) {
        byte_acc[j][0] <== 0;
        for (var k = 0; k < 8; k++) {
            byte_acc[j][k+1] <== byte_acc[j][k] + bits[j*8 + k] * (1 << k);
        }
        out[j] <== byte_acc[j][8];
    }

    // Last byte only has 7 bits
    byte_acc[31][0] <== 0;
    for (var k = 0; k < 7; k++) {
        byte_acc[31][k+1] <== byte_acc[31][k] + bits[31*8 + k] * (1 << k);
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
// [INFO]  snarkJS: # of Wires: 55741
// [INFO]  snarkJS: # of Constraints: 56027
// [INFO]  snarkJS: # of Private Inputs: 12
// [INFO]  snarkJS: # of Public Inputs: 0
// [INFO]  snarkJS: # of Labels: 113080
// [INFO]  snarkJS: # of Outputs: 32