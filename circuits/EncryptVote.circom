pragma circom 2.2.2;

include "ed25519/point-addition.circom";
include "ed25519/scalar-multiplication.circom";

template EncryptVote() {
    signal input election_public_key[4][3]; // aka `recipient`, chunkedRistrettoPoint
    signal input encoded_vote_to_secretly_cancel[4][3]; // chunkedRistrettoPoint
    signal input votes_secret_randomizer[255]; // bitify(bigint)

    // TODO: Enforce that encoded_vote_to_secretly_cancel is prime-order
    // component enforcePrimeOrder = EnforcePrimeOrder()
    // enforcePrimeOrder.P <== encoded_vote_to_secretly_cancel


    // We recalculate the encrypted ciphertext using the Elliptic Curve ElGamal algorithm:
    // Encrypted = Encoded + (Recipient * randomizer)

    // First we calc the shared secret: recipient * randomizer
    signal shared_secret[4][3];
    shared_secret <== ScalarMul()(votes_secret_randomizer, election_public_key);

    // Then we add the encoded vote to the shared secret
    signal output encrypted_vote[4][3];
    encrypted_vote <== PointAdd()(encoded_vote_to_secretly_cancel, shared_secret);
}

// npx snarkjs r1cs info build/EncryptVote.r1cs
// [INFO]  snarkJS: Curve: bn-128
// [INFO]  snarkJS: # of Wires: 1946468
// [INFO]  snarkJS: # of Constraints: 1969648
// [INFO]  snarkJS: # of Private Inputs: 279
// [INFO]  snarkJS: # of Public Inputs: 0
// [INFO]  snarkJS: # of Labels: 5578984
// [INFO]  snarkJS: # of Outputs: 12

// With o2 optimizations: 38% less wires & constraints
// [INFO]  snarkJS: Curve: bn-128
// [INFO]  snarkJS: # of Wires: 1206958
// [INFO]  snarkJS: # of Constraints: 1230138
// [INFO]  snarkJS: # of Private Inputs: 279
// [INFO]  snarkJS: # of Public Inputs: 0
// [INFO]  snarkJS: # of Labels: 5578984
// [INFO]  snarkJS: # of Outputs: 12