pragma circom 2.2.2;

include "poseidon.circom";

// To hash a Ristretto Point, which is a 4x3 array of arrays:
// [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]]
// hash4( hash3([1,2,3]), hash3([4,5,6]), hash3([7,8,9]), hash3([10,11,12]) )
template HashPoint() {
    signal input point_to_hash[4][3];
    signal output hash;

    signal x_hash <== Poseidon(3)([point_to_hash[0][0], point_to_hash[0][1], point_to_hash[0][2]]);
    signal y_hash <== Poseidon(3)([point_to_hash[1][0], point_to_hash[1][1], point_to_hash[1][2]]);
    signal z_hash <== Poseidon(3)([point_to_hash[2][0], point_to_hash[2][1], point_to_hash[2][2]]);
    signal t_hash <== Poseidon(3)([point_to_hash[3][0], point_to_hash[3][1], point_to_hash[3][2]]);
    hash <== Poseidon(4)([x_hash, y_hash, z_hash, t_hash]);
}
