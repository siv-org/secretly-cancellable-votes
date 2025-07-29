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
    signal input rootHashOfAllEncryptedVotes; // poseidon_hash
    signal input electionPublicKey[4][3]; // RistrettoPoint.toBytes()
    signal input actualTreeDepth;

    // Private inputs
    signal input encodedVoteToSecretlyCancel[4][3]; // Ristretto Point
    signal input voteSecretRandomizer[255]; // bitify(bigint)

    signal input merklePathOfCancelledVote[MAX_TREE_DEPTH]; // poseidon_hash[]
    signal input merklePathIndex; // integer
    signal input adminSecretSalt; // bigint

    signal input jsEncryptedVoteToCancel[4][3]; // Ristretto Point calculated in JS 

    // 1) Confirm encrypted vote is in the tree
    // 1a) First we need to encrypt our vote again
    signal encryptedVoteToCancel[4][3];
    encryptedVoteToCancel <== EncryptVote()(electionPublicKey, encodedVoteToSecretlyCancel, voteSecretRandomizer);

    AssertEqualRPPoints()(encryptedVoteToCancel, jsEncryptedVoteToCancel);
  
    // Note: Because the above call depends on `votes_secret_randomizer`, it also helps prevent admin from cancelling unauthorized votes, since only voter knows the randomizer, not admin.

    // 1b) Then we use the merkle path to prove it's in the set of all encrypted votes
    MembershipProof(MAX_TREE_DEPTH)(jsEncryptedVoteToCancel, actualTreeDepth, merklePathIndex, merklePathOfCancelledVote, rootHashOfAllEncryptedVotes);

    // Public outputs

    // 2) Prove the cancelled vote content
    var MAX_VOTE_CONTENT_LENGTH = 32 - 1 - 15; // 32 - length_byte - 15_bytes_for_verification_number
    signal output voteSelectionToCancel[MAX_VOTE_CONTENT_LENGTH]; // integer[], eg. 'abca' -> [97, 98, 99, 97]
    voteSelectionToCancel <== ExtractSelectionFromVote()(RistrettoToBytes()(encodedVoteToSecretlyCancel));

    // 3) Prove the cancelled vote is unique
    var hashedEncodedVoteToSecretlyCancel = HashPoint()(encodedVoteToSecretlyCancel);
    signal output saltedHashOfVoteToCancel <== Poseidon(2)([adminSecretSalt, hashedEncodedVoteToSecretlyCancel]);

    // 3b) Prove the admin's secret salt is consistent across all cancelled votes
    signal output hashOfAdminSecretSalt <== HashAdminSalt()(adminSecretSalt);
}
