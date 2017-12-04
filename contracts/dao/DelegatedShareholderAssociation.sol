/*

  Delegated self-upgrading shareholders association.

  Originally based on the Shareholder Association example from https://ethereum.org/dao.
  
  Modified to support vote delegation and self-ownership - modifications in detail:

    Delegation

      Overview

        Any shareholder in the DAO (which is anyone who holds the associated token) can voluntarily delegate any portion of their tokens to another address.
        They do so by sending the tokens which they wish to delegate to the DAO, which locks them until the user undelegates their tokens (at which point the DAO returns the tokens to the user).
        While locked, these tokens count as extra votes for the address to whom the user delegated their tokens.
        Tokens can be unlocked at any time, and once unlocked no longer count as delegated votes in this manner.

      Notes

        - Delegated votes are counted when a proposal is finalized and executed (or not) - there's no way to move tokens around to create more votes than tokens and/or cause any tokens to count twice.
        - The DAO is prevented from spending these locked tokens in the executeProposal function, so users who lock tokens are guaranteed the ability to withdraw them whenever they choose (no reserve banking).

    Self-Ownership

      Only the DAO itself can change its own voting rules (not an owning address). 

  TODO

    - Convenience constant function for vote tallying
    - Clarify some documentation

*/

pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/token/ERC20.sol";
import "../common/TokenRecipient.sol";

contract DelegatedShareholderAssociation is TokenRecipient {

    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    Proposal[] public proposals;
    uint public numProposals;
    ERC20 public sharesTokenAddress;

    mapping (address => address) public delegatesByDelegator;
    mapping (address => uint) public lockedDelegatingTokens;
    mapping (address => uint) public delegatedAmountsByDelegate;
    uint public totalLockedTokens;

    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, uint result, uint quorum, bool active);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes, address newSharesTokenAddress);

    event TokensDelegated(address indexed delegator, uint numberOfTokens, address indexed delegate);
    event TokensUndelegated(address indexed delegator, uint numberOfTokens, address indexed delegate);

    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        address voter;
    }

    /* Only shareholders can execute a function with this modifier. */
    modifier onlyShareholders {
        require(sharesTokenAddress.balanceOf(msg.sender) > 0);
        _;
    }

    /* Only the DAO itself (via an approved proposal) can execute a function with this modifier. */
    modifier onlySelf {
        require(msg.sender == address(this));
        _;
    }

    /* Only a shareholder who has *not* delegated his vote can execute a function with this modifier. */
    modifier onlyUndelegated {
        require(delegatesByDelegator[msg.sender] == address(0));
        _;
    }

    /* Only a shareholder who has delegated his vote can execute a function with this modifier. */
    modifier onlyDelegated {
        require(delegatesByDelegator[msg.sender] != address(0));
        _;
    }

    /** 
      * @notice Set the delegate address for a specified number of tokens belonging to the sending address, locking the tokens.
      * @dev An address holding tokens (shares) may only delegate some portion of their vote to one delegate at any one time
      * @param tokensToLock number of tokens to be locked (sending address must have at least this many tokens)
      * @param delegate the address to which votes equal to the number of tokens locked will be delegated
      */
    function setDelegateAndLockTokens(uint tokensToLock, address delegate) onlyUndelegated  public {
        require(ERC20(sharesTokenAddress).transferFrom(msg.sender, address(this), tokensToLock));
        lockedDelegatingTokens[msg.sender] = tokensToLock;
        delegatedAmountsByDelegate[delegate] = tokensToLock;
        totalLockedTokens += tokensToLock;
        TokensDelegated(msg.sender, tokensToLock, delegate);
    }

    /** 
     * @notice Clear the delegate address for all tokens delegated by the sending address, unlocking the locked tokens.
     * @dev Can only be called by a sending address currently delegating tokens, will transfer all locked tokens back to the sender
     */
    function clearDelegateAndUnlockTokens() public onlyDelegated {
        address delegate = delegatesByDelegator[msg.sender];
        uint lockedTokens = lockedDelegatingTokens[msg.sender];
        lockedDelegatingTokens[msg.sender] = 0;
        delegatedAmountsByDelegate[delegate] -= lockedTokens;
        totalLockedTokens -= lockedTokens;
        require(ERC20(sharesTokenAddress).transfer(msg.sender, lockedTokens));
        TokensUndelegated(msg.sender, lockedTokens, delegate);
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need tobe discussed for at least `minutesForDebate/60` hours
     * and all voters combined must own more than `minimumSharesToPassAVote` shares of token `sharesAddress` to be executed
     *
     * @param minimumSharesToPassAVote proposal can vote only if the sum of shares held by all voters exceed this number
     * @param minutesForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     */
    function changeVotingRules(uint minimumSharesToPassAVote, uint minutesForDebate) onlySelf  public {
        if (minimumSharesToPassAVote == 0 ) {
            minimumSharesToPassAVote = 1;
        }
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;
        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, sharesTokenAddress);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send, in wei
     * @param jobDescription Description of job
     * @param transactionBytecode bytecode of transaction
     */
    function newProposal(
        address beneficiary,
        uint weiAmount,
        string jobDescription,
        bytes transactionBytecode
    )
        public
        onlyShareholders
        returns (uint proposalID)
    {
        proposalID = proposals.length++;
        Proposal storage p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.description = jobDescription;
        p.proposalHash = keccak256(beneficiary, weiAmount, transactionBytecode);
        p.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        ProposalAdded(proposalID, beneficiary, weiAmount, jobDescription);
        numProposals = proposalID+1;

        return proposalID;
    }

    /**
     * Add proposal in Ether
     *
     * Propose to send `etherAmount` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     * This is a convenience function to use if the amount to be given is in round number of ether units.
     *
     * @param beneficiary who to send the ether to
     * @param etherAmount amount of ether to send
     * @param jobDescription Description of job
     * @param transactionBytecode bytecode of transaction
     */
    function newProposalInEther(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode
    )
        public
        onlyShareholders
        returns (uint proposalID)
    {
        return newProposal(beneficiary, etherAmount * 1 ether, jobDescription, transactionBytecode);
    }

    /**
     * Check if a proposal code matches
     *
     * @param proposalNumber ID number of the proposal to query
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send
     * @param transactionBytecode bytecode of transaction
     */
    function checkProposalCode(
        uint proposalNumber,
        address beneficiary,
        uint weiAmount,
        bytes transactionBytecode
    )
        public
        constant
        returns (bool codeChecksOut)
    {
        Proposal storage p = proposals[proposalNumber];
        return p.proposalHash == keccak256(beneficiary, weiAmount, transactionBytecode);
    }

    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
     *
     * @param proposalNumber number of proposal
     * @param supportsProposal either in favor or against it
     */
    function vote(
        uint proposalNumber,
        bool supportsProposal
    )
        public
        onlyShareholders
        returns (uint voteID)
    {
        Proposal storage p = proposals[proposalNumber];
        require(p.voted[msg.sender] != true);

        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteID + 1;
        Voted(proposalNumber,  supportsProposal, msg.sender);
        return voteID;
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     *
     * @param proposalNumber proposal number
     * @param transactionBytecode optional: if the transaction contained a bytecode, you need to send it
     */
    function executeProposal(uint proposalNumber, bytes transactionBytecode)  public {
        Proposal storage p = proposals[proposalNumber];

        /* If past deadline, not already executed, and code is correct, keep going. */
        require((now > p.votingDeadline) && !p.executed && p.proposalHash == keccak256(p.recipient, p.amount, transactionBytecode));

        // ...then tally the results
        uint quorum = 0;
        uint yea = 0;
        uint nay = 0;

        for (uint i = 0; i < p.votes.length; ++i) {
            Vote storage v = p.votes[i];
            uint voteWeight = sharesTokenAddress.balanceOf(v.voter) + delegatedAmountsByDelegate[v.voter];
            quorum += voteWeight;
            if (v.inSupport) {
                yea += voteWeight;
            } else {
                nay += voteWeight;
            }
        }

        /* Assert that a minimum quorum has been reached. */
        require(quorum >= minimumQuorum);

        if (yea > nay) {
            // Proposal passed; execute the transaction

            p.executed = true;
            require(p.recipient.call.value(p.amount)(transactionBytecode));

            /* Prevent the DAO from sending the locked shares tokens (and thus potentially being unable to release locked tokens to delegating shareholders). */
            require(ERC20(sharesTokenAddress).balanceOf(address(this)) >= totalLockedTokens);

            p.proposalPassed = true;
        } else {
            // Proposal failed
            p.proposalPassed = false;
        }

        // Fire Events
        ProposalTallied(proposalNumber, yea - nay, quorum, p.proposalPassed);
    }
}
