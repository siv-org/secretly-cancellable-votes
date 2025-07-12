pragma circom 2.2.2;

include "bitify.circom";
include "ed25519/chunkedadd.circom";
include "ed25519/chunkedsub.circom";
include "ed25519/chunkedmul.circom";
include "ChunkedSqrt.circom";
// include "./ChunkedModP.circom";

template RistrettoToBytes() {
    // Input: x, y, z, t in chunked form
    signal input P[4][3];

    // Output compressed s in bytes
    signal output s_bytes[32];

    var base = 85;

    // Constants for Ristretto encoding, in chunked form
    var SQRT_M1_WHOLE = 19681161376707505956807079304988542015446066515923890162744021073123829784752;
    var SQRT_M1[3] = [SQRT_M1_WHOLE % (1 << base),
                      (SQRT_M1_WHOLE >> base) % (1 << base),
                      (SQRT_M1_WHOLE >> (2 * base)) % (1 << base)];

    var INVSQRT_A_MINUS_D_WHOLE = 54469307008909316920995813868745141605393597292927456921205312896311721017578;
    var INVSQRT_A_MINUS_D[3] = [INVSQRT_A_MINUS_D_WHOLE % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> base) % (1 << base),
                                (INVSQRT_A_MINUS_D_WHOLE >> (2 * base)) % (1 << base)];

    // Step 1: u1 = mod((z + y) * (z - y))
    component z_plus_y = ChunkedAdd(3, 2, base);
    component z_minus_y = ChunkedSubModP(3, base);
    for (var i = 0; i < 3; i++) {
        z_plus_y.in[0][i] <== P[2][i]; // z
        z_plus_y.in[1][i] <== P[1][i]; // y
        z_minus_y.a[i] <== P[2][i];
        z_minus_y.b[i] <== P[1][i];
    }

    component u1_premod = ChunkedMul(3, 3, base);
    for (var i = 0; i < 3; i++) {
        u1_premod.in1[i] <== z_plus_y.out[i];
        u1_premod.in2[i] <== z_minus_y.out[i];
    }

    // component u1 = ChunkedModP(6, base);
    // for (var i = 0; i < 6; i++) {
    //     u1.in[i] <== u1_premod.out[i];
    // }

    // // Step 2: u2 = x * y
    // component mul_u2 = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_u2.in1[i] <== P[0][i]; // x
    //     mul_u2.in2[i] <== P[1][i]; // y
    // }

    // // Step 3: invsqrt = invertSqrt(u1 * u2^2)
    // component sq_u2 = ChunkedSquare(3, base);
    // for (var i = 0; i < 3; i++) {
    //     sq_u2.a[i] <== mul_u2.out[i];
    // }

    // component mul_sqrt = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_sqrt.in1[i] <== u1.out[i];
    //     mul_sqrt.in2[i] <== sq_u2.out[i];
    // }

    // component invsqrt = ChunkedInvertSqrt(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     invsqrt.a[i] <== mul_sqrt.out[i];
    // }

    // // Step 4: D1 = invsqrt * u1
    // component mul_D1 = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_D1.in1[i] <== invsqrt.out[i];
    //     mul_D1.in2[i] <== u1.out[i];
    // }

    // // Step 5: D2 = invsqrt * u2
    // component mul_D2 = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_D2.in1[i] <== invsqrt.out[i];
    //     mul_D2.in2[i] <== mul_u2.out[i];
    // }

    // // Step 6: zInv = D1 * D2 * t
    // component mul_zInv_temp = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_zInv_temp.in1[i] <== mul_D1.out[i];
    //     mul_zInv_temp.in2[i] <== mul_D2.out[i];
    // }

    // component mul_zInv = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_zInv.in1[i] <== mul_zInv_temp.out[i];
    //     mul_zInv.in2[i] <== P[3][i]; // t
    // }

    // // Step 7: Check if t * zInv is negative
    // component mul_t_zInv = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_t_zInv.in1[i] <== P[3][i]; // t
    //     mul_t_zInv.in2[i] <== mul_zInv.out[i];
    // }

    // component isNegative_t_zInv = IsNegativeChunked(3, base);
    // for (var i = 0; i < 3; i++) {
    //     isNegative_t_zInv.in[i] <== mul_t_zInv.out[i];
    // }

    // // Step 8: Conditional swap based on t * zInv sign
    // // If t * zInv is negative, we need to swap x and y with sqrt(-1) factors
    // // x' = y * sqrt(-1), y' = x * sqrt(-1)
    // component mul_x_sqrt_m1 = ChunkedMul(3, 3, base);
    // component mul_y_sqrt_m1 = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_x_sqrt_m1.in1[i] <== P[0][i]; // x
    //     mul_x_sqrt_m1.in2[i] <== SQRT_M1[i];
    //     mul_y_sqrt_m1.in1[i] <== P[1][i]; // y
    //     mul_y_sqrt_m1.in2[i] <== SQRT_M1[i];
    // }

    // component mux_x = Multiplexor2(3);
    // component mux_y = Multiplexor2(3);
    // mux_x.sel <== isNegative_t_zInv.out;
    // mux_y.sel <== isNegative_t_zInv.out;
    // for (var i = 0; i < 3; i++) {
    //     mux_x.in[0][i] <== P[0][i]; // original x
    //     mux_x.in[1][i] <== mul_y_sqrt_m1.out[i]; // y * sqrt(-1)
    //     mux_y.in[0][i] <== P[1][i]; // original y
    //     mux_y.in[1][i] <== mul_x_sqrt_m1.out[i]; // x * sqrt(-1)
    // }

    // // Step 9: Check if x * zInv is negative
    // component mul_x_zInv = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_x_zInv.in1[i] <== mux_x.out[i];
    //     mul_x_zInv.in2[i] <== mul_zInv.out[i];
    // }

    // component isNegative_x_zInv = IsNegativeChunked(3, base);
    // for (var i = 0; i < 3; i++) {
    //     isNegative_x_zInv.in[i] <== mul_x_zInv.out[i];
    // }

    // // Step 10: Conditional negation of y based on x * zInv sign
    // component neg_y = ChunkedNeg(3, base);
    // for (var i = 0; i < 3; i++) {
    //     neg_y.in[i] <== mux_y.out[i];
    // }

    // component mux_y_final = Multiplexor2(3);
    // mux_y_final.sel <== isNegative_x_zInv.out;
    // for (var i = 0; i < 3; i++) {
    //     mux_y_final.in[0][i] <== mux_y.out[i]; // original y
    //     mux_y_final.in[1][i] <== neg_y.out[i]; // negated y
    // }

    // // Step 11: Compute s = (z - y) * D
    // component sub_z_y_final = ChunkedSub(3, base);
    // for (var i = 0; i < 3; i++) {
    //     sub_z_y_final.a[i] <== P[2][i]; // z
    //     sub_z_y_final.b[i] <== mux_y_final.out[i]; // adjusted y
    // }

    // // Choose D based on t * zInv sign
    // component mul_D1_invsqrt = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_D1_invsqrt.in1[i] <== mul_D1.out[i];
    //     mul_D1_invsqrt.in2[i] <== INVSQRT_A_MINUS_D[i];
    // }

    // component mux_D = Multiplexor2(3);
    // mux_D.sel <== isNegative_t_zInv.out;
    // for (var i = 0; i < 3; i++) {
    //     mux_D.in[0][i] <== mul_D2.out[i]; // D2
    //     mux_D.in[1][i] <== mul_D1_invsqrt.out[i]; // D1 * INVSQRT_A_MINUS_D
    // }

    // component mul_s = ChunkedMul(3, 3, base);
    // for (var i = 0; i < 3; i++) {
    //     mul_s.in1[i] <== sub_z_y_final.out[i];
    //     mul_s.in2[i] <== mux_D.out[i];
    // }

    // // Ensure s is positive (if negative, negate it)
    // component isNegative_s = IsNegativeChunked(3, base);
    // for (var i = 0; i < 3; i++) {
    //     isNegative_s.in[i] <== mul_s.out[i];
    // }

    // component neg_s = ChunkedNeg(3, base);
    // for (var i = 0; i < 3; i++) {
    //     neg_s.in[i] <== mul_s.out[i];
    // }

    // component mux_s_final = Multiplexor2(3);
    // mux_s_final.sel <== isNegative_s.out;
    // for (var i = 0; i < 3; i++) {
    //     mux_s_final.in[0][i] <== mul_s.out[i]; // original s
    //     mux_s_final.in[1][i] <== neg_s.out[i]; // negated s
    // }

    // // Convert final s to bytes
    // component sToBytes = ChunkedToBytes(3, base);
    // for (var i = 0; i < 3; i++) {
    //     sToBytes.in[i] <== mux_s_final.out[i];
    // }

    // for (var i = 0; i < 32; i++) {
    //     s_bytes[i] <== sToBytes.out[i];
    // }

    // // Debug
    // 3-limbed signals
    signal z_plus_y_out[3];
    signal z_minus_y_out[3];
    for (var i = 0; i < 3; i++) {
        z_plus_y_out[i] <== z_plus_y.out[i];
        z_minus_y_out[i] <== z_minus_y.out[i];
    }

    // 6-limbed signals
    signal u1_premod_out[6];
    for (var i = 0; i < 6; i++) {
        u1_premod_out[i] <== u1_premod.out[i];
    }
    // End debug
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

template ChunkedNeg(chunks, chunkbits) {
    signal input in[chunks];
    signal output out[chunks];

    var max_val = (1 << chunkbits) - 1;
    for (var i = 0; i < chunks; i++) {
        out[i] <== max_val - in[i];
    }
}

template IsNegativeChunked(chunks, chunkbits) {
    signal input in[chunks];
    signal output out;

    // Check if the least significant bit of the first chunk is 1
    // This indicates negativity in little-endian representation
    component bits = Num2Bits(chunkbits);
    bits.in <== in[0];
    out <== bits.out[0];
}

template ChunkedToBytes(chunks, chunkbits) {
    signal input in[chunks];
    signal output out[32];

    var totalbits = chunks * chunkbits; // should be 255

    assert(totalbits == 255); // sanity check

    component bits = Num2Bits(255);

    // Flatten
    signal acc[chunks + 1];
    acc[0] <== 0;
    for (var i = 0; i < chunks; i++) {
        acc[i+1] <== acc[i] + in[i] * (1 << (i * chunkbits));
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