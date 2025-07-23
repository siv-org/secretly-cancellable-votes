pragma circom 2.2.2;

include "EncryptVote.circom";
include "ExtractSelectionFromVote.circom";
include "MembershipProof.circom";
include "MerkleRoot.circom";
include "poseidon.circom";
include "HashAdminSalt.circom";
include "HashPoint.circom";
include "RistrettoToBytes.circom";
include "./AssertEqualRPPoints.circom";

/**
Verification #: 4470-7655-8313

icecream
  plaintext: 4470-7655-8313:Pistacchio
  encoded: 32343437302d373635352d383331333a5069737461636368696f77329d87430f
  randomizer: 1824575995961533715804695610269531409259964862024837291270780613852485667720
    encrypted: 66a82bb523bddf2a1d9ea1de7cdf65f04ee17716edfa20dfb5c16301e4dd9a70
    lock: 6671f6d6d4e4993aec2b44f0e6c6f34211b062c0a70f80989d2bc075ba384146
*/
template SecretlyCancelVote(MAX_TREE_DEPTH) {
    // Public inputs
    signal input root_hash_of_all_encrypted_votes; // poseidon_hash
    signal input election_public_key[4][3]; // RistrettoPoint.toBytes()
    signal input actual_tree_depth;

    // Private inputs
    signal input encoded_vote_to_secretly_cancel[4][3]; // Ristretto Point
    signal input votes_secret_randomizer[255]; // bitify(bigint)

    signal input merkle_path_of_cancelled_vote[MAX_TREE_DEPTH]; // poseidon_hash[]
    signal input merkle_path_index; // integer
    signal input admin_secret_salt; // bigint

    signal input js_encrypted_vote_to_cancel[4][3]; // Ristretto Point calculated in JS 

    // 1) Confirm encrypted vote is in the tree
    // 1a) First we need to encrypt our vote again
    signal encrypted_vote_to_cancel[4][3];
    encrypted_vote_to_cancel <== EncryptVote()(election_public_key, encoded_vote_to_secretly_cancel, votes_secret_randomizer);

    AssertEqualRPPoints()(encrypted_vote_to_cancel, js_encrypted_vote_to_cancel);
  
    // Note: Because the above call depends on `votes_secret_randomizer`, it also helps prevent admin from cancelling unauthorized votes, since only voter knows the randomizer, not admin.

    // 1b) Then we use the merkle path to prove it's in the set of all encrypted votes
    MembershipProof(MAX_TREE_DEPTH)(js_encrypted_vote_to_cancel, actual_tree_depth, merkle_path_index, merkle_path_of_cancelled_vote, root_hash_of_all_encrypted_votes);

    // Public outputs

    // 2) Prove the cancelled vote content
    var MAX_VOTE_CONTENT_LENGTH = 32 - 1 - 15; // 32 - length_byte - 15_bytes_for_verification_number
    signal output vote_selection_to_cancel[MAX_VOTE_CONTENT_LENGTH]; // integer[], eg. 'abca' -> [97, 98, 99, 97]
    vote_selection_to_cancel <== ExtractSelectionFromVote()(RistrettoToBytes()(encoded_vote_to_secretly_cancel));

    // 3) Prove the cancelled vote is unique
    var hashed_encoded_vote_to_secretly_cancel = HashPoint()(encoded_vote_to_secretly_cancel);
    signal output salted_hash_of_vote_to_cancel <== Poseidon(2)([admin_secret_salt, hashed_encoded_vote_to_secretly_cancel]);

    // 3b) Prove the admin's secret salt is consistent across all cancelled votes
    signal output hash_of_admin_secret_salt <== HashAdminSalt()(admin_secret_salt);
}

// npx snarkjs r1cs info build/SecretlyCancelVote.r1cs
// [INFO]  snarkJS: Curve: bn-128
// [INFO]  snarkJS: # of Wires: 2050548
// [INFO]  snarkJS: # of Constraints: 2074036
// [INFO]  snarkJS: # of Private Inputs: 297
// [INFO]  snarkJS: # of Public Inputs: 14
// [INFO]  snarkJS: # of Labels: 6203479
// [INFO]  snarkJS: # of Outputs: 18
