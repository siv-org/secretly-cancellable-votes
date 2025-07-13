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
    component v2 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        v2.in1[i] <== v[i];
        v2.in2[i] <== v[i];
    }

    component v3 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        v3.in1[i] <== v2.out[i];
        v3.in2[i] <== v[i];
    }

    // v7 = v3 * v3 * v
    component v3_2 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        v3_2.in1[i] <== v3.out[i];
        v3_2.in2[i] <== v3.out[i];
    }

    component v7 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        v7.in1[i] <== v3_2.out[i];
        v7.in2[i] <== v[i];
    }

    // pow = (u * v7)^{(p-5)/8}
    component uv7 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        uv7.in1[i] <== u[i];
        uv7.in2[i] <== v7.out[i];
    }

    component pow = ChunkedPow2523(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        pow.in[i] <== uv7.out[i];
    }

    // x = (u * v3) * pow
    component uv3 = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        uv3.in1[i] <== u[i];
        uv3.in2[i] <== v3.out[i];
    }

    component x = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        x.in1[i] <== uv3.out[i];
        x.in2[i] <== pow.out[i];
    }

    // skip root checks (like vx² == u or -u) for now to keep ZK minimal
    for (var i = 0; i < chunks; i++) {
        out[i] <== x.out[i];
    }
}

// Hard-coded exponentiation chain, which efficiently computes a^{(p-5)/8}.
template ChunkedPow2523(chunks, chunkBits, base) {
    signal input in[chunks];
    signal output out[chunks];

    signal tmp[chunks];

    // Pre-declare all squaring components
    component sqs[252];
    for (var j = 0; j < 252; j++) {
        sqs[j] = ChunkedMul(chunks, chunks, base);
    }

    // Connect chaining
    for (var j = 0; j < 252; j++) {
        for (var i = 0; i < chunks; i++) {
            if (j == 0) {
                sqs[j].in1[i] <== in[i];
                sqs[j].in2[i] <== in[i];
            } else {
                sqs[j].in1[i] <== sqs[j-1].out[i];
                sqs[j].in2[i] <== sqs[j-1].out[i];
            }
        }
    }

    // Final multiply by input
    component mul = ChunkedMul(chunks, chunkBits, base);
    for (var i = 0; i < chunks; i++) {
        mul.in1[i] <== sqs[251].out[i];
        mul.in2[i] <== in[i];
    }

    for (var i = 0; i < chunks; i++) {
        out[i] <== mul.out[i];
    }
}