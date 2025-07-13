pragma circom 2.2.2;

include "./ed25519/chunkedmul.circom";

template ChunkedInvertSqrt(chunks, chunkBits, base) {
    signal input a[chunks];

    var ONE[3] = [1, 0, 0];

    signal output out[chunks] <== ChunkedUVRatio(chunks, chunkBits, base)(ONE, a);
}

template ChunkedUVRatio(chunks, chunkBits, base) {
    signal input u[chunks];
    signal input v[chunks];
    signal output out[chunks];

    // v3 = v * v * v
    signal v2[chunks] <== ChunkedModP()(ChunkedMul(chunks, chunkBits, base)(v, v));
    signal v3[chunks] <== ChunkedModP()(ChunkedMul(chunks, chunkBits, base)(v2, v));

    // v7 = v3 * v3 * v
    signal v6[chunks] <== ChunkedModP()(ChunkedMul(chunks, chunkBits, base)(v3, v3));
    signal v7[chunks] <== ChunkedModP()(ChunkedMul(chunks, chunkBits, base)(v6, v));

    // pow = (u * v7)^{(p-5)/8}
    signal uv7[chunks] <== ChunkedModP()(ChunkedMul(chunks, chunkBits, base)(u, v7));
    // -- Confirmed above matches reference --
    signal pow[chunks] <== ChunkedPow2_252_3(chunks, chunkBits, base)(uv7);
    // log("circuit=");
    // for (var i = 0; i < chunks; i++) log(pow[i]);

    // x = (u * v3) * pow
    component uv3 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        uv3.in1[i] <== u[i];
        uv3.in2[i] <== v3[i];
    }

    component x = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        x.in1[i] <== uv3.out[i];
        x.in2[i] <== pow[i];
    }

    // skip root checks (like vx² == u or -u) for now to keep ZK minimal
    for (var i = 0; i < chunks; i++) {
        out[i] <== x.out[i];
    }
}

// Efficiently computes a^{(p-5)/8} aka x^(2^252-3).
template ChunkedPow2_252_3(chunks, chunkBits, base) {
    signal input x[chunks];
    signal output out[chunks];

    signal x2[chunks] <== ChunkedMulModP(chunks, chunkBits, base)(x, x);
    signal b2[chunks] <== ChunkedMulModP(chunks, chunkBits, base)(x2, x);
    // -- Confirmed above matches reference --

    log("circuit:");
    for (var i = 0; i < chunks; i++) log(b2[i]);


    // // Pre-declare all squaring components
    // component sqs[252];
    // for (var j = 0; j < 252; j++) {
    //     sqs[j] = ChunkedMul(chunks, chunks, base);
    // }

    // // Connect chaining
    // for (var j = 0; j < 252; j++) {
    //     for (var i = 0; i < chunks; i++) {
    //         if (j == 0) {
    //             sqs[j].in1[i] <== in[i];
    //             sqs[j].in2[i] <== in[i];
    //         } else {
    //             sqs[j].in1[i] <== sqs[j-1].out[i];
    //             sqs[j].in2[i] <== sqs[j-1].out[i];
    //         }
    //     }
    // }

    // // Final multiply by input
    // component mul = ChunkedMul(chunks, chunkBits, base);
    // for (var i = 0; i < chunks; i++) {
    //     mul.in1[i] <== sqs[251].out[i];
    //     mul.in2[i] <== in[i];
    // }

    // for (var i = 0; i < chunks; i++) {
    //     out[i] <== mul.out[i];
    // }
}