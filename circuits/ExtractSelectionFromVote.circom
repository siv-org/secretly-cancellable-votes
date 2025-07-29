pragma circom 2.2.2;

include "ExtractStringFromPoint.circom";

// Given a string with the vote and identifier, extract the vote selection only
template ExtractSelectionFromVote() {
    var bytesPerPoint = 32;
    var maxLength = bytesPerPoint - 1; // 1st byte is for length
    var START_INDEX = 15; // 15 bytes for verification number

    // Input: serialized point as bytes
    signal input pointAsBytes[bytesPerPoint];

    // Extract the full vote string from the point
    signal stringAsBytes[maxLength] <== ExtractStringFromPoint()(pointAsBytes);

    // Extract just the vote selection from the vote string
    signal output choice[maxLength - START_INDEX];
    for (var i = START_INDEX; i < maxLength; i++) {
        choice[i - START_INDEX] <== stringAsBytes[i];
    }
}
