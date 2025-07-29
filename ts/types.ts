import { ChunkedPoint } from "./utils"

/**
 * The inputs for the circuit
 */
export interface ICircuitInputs {
    /**
     * The root hash of all encrypted votes
     */
    rootHashOfAllEncryptedVotes: bigint
    /**
     * The public key of the election
     */
    electionPublicKey: ChunkedPoint
    /**
     * The depth of the merkle tree
     */
    actualTreeDepth: bigint
    /**
     * The encoded vote to secretly cancel
     */
    encodedVoteToSecretlyCancel: ChunkedPoint
    /**
     * The vote secret randomizer
     */
    voteSecretRandomizer: bigint[]
    /**
     * The merkle path of the cancelled vote
     */
    merklePathOfCancelledVote: bigint[]
    /**
     * The index of the leaf in the tree
     */
    merklePathIndex: bigint
    /**
     * The admin secret salt
     */
    adminSecretSalt: bigint
    /**
     * The encrypted vote to cancel calculated in JS
     */
    jsEncryptedVoteToCancel: ChunkedPoint
}

/**
 * The type of election
 */
export enum ElectionType {
  /**
   * Ranked choice election
   */
  RankedChoice = "ranked-choice-irv",
  /**
   * Choose only one option
   */
  ChooseOnlyOne = "choose-only-one",
  /**
   * Approval voting
   */
  Approval = "approval",
  /**
   * Multiple votes allowed
   */
  MultipleVotesAllowed = "multiple-votes-allowed",
  /**
   * Budget voting
   */
  Budget = "budget"
}

/**
 * The config for running a secret cancellation
 */
export interface IConfig {
    /**
     * The endpoint to fetch votes from
     */
    endpoint: string
    /**
     * The path to the zkey file
     */
    zKeyPath: string
    /**
     * The path to the wasm file
     */
    wasmPath: string
    /**
     * The election public key
     */
    electionPublicKey: string
    /**
     * The votes secret randomizer
     */
    voteSecretRandomizer: string
    /**
     * The admin secret salt
     */ 
    adminSecretSalt: string
    /**
     * The question Id for which to cancel a vote
     */
    questionId?: string
    /**
     * The type of election
     */
    electionType: ElectionType
    /**
     * The encoded vote to cancel
     */
    encodedVoteToCancel: string
}

/**
 * The data stored by the SIV sever for each vote
 */
export interface IEncryptedAndLock {
    encrypted: string
    lock: boolean
  }
  
  /**
   * The SIV API returns a JSON object with the following structure:
   */
  export interface ISIVVote {
    auth: string
    [key: string]: IEncryptedAndLock | string
  }
  
  /**
   * An interface to represent the data we need from the vote
   */
  export interface IVoteResult {
    option: string
    encrypted: string
  }
  
  /**
   * A group of votes by option
   */
  export interface IGroupedVotes {
    [option: string]: string[]
  }
