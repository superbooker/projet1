/*
::::::::::: :::::::::    :::           :::     :::        :::::::::: :::    :::  :::   ::: :::::::::: 
    :+:     :+:    :+: :+:+:         :+: :+:   :+:        :+:        :+:    :+:  :+:   :+: :+:        
    +:+     +:+    +:+   +:+        +:+   +:+  +:+        +:+         +:+  +:+    +:+ +:+  +:+        
    +#+     +#++:++#+    +#+       +#++:++#++: +#+        +#++:++#     +#++:+      +#++:   +#++:++#   
    +#+     +#+          +#+       +#+     +#+ +#+        +#+         +#+  +#+      +#+    +#+        
    #+#     #+#          #+#       #+#     #+# #+#        #+#        #+#    #+#     #+#    #+#        
    ###     ###        #######     ###     ### ########## ########## ###    ###     ###    ########## 
*/
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Voting is Ownable{
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
        uint numberOfProposals;
    }
    struct Proposal {
        string description;
        uint voteCount;
        address addressOfProposalPerson;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    enum TypeOfMajority {
        SimpleMajority,
        AbsoluteMajority
    }

    //Variables_________________________________________________________________________________________________________________________________________________________
    mapping (address => Voter) public voters;
    //address[] public addressOfvoters;
    Proposal[] public proposals;
    uint[] ballotArray;
    uint qorum;
    uint winningProposalId;
    uint public randomizerNonce;
    WorkflowStatus currentWorkflowStatus;
    uint[] public headProposalIds;



    //Events___________________________________________________________________________________________________________________________________________________________
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    event AndTheWinnerIs(uint proposalId);
    event voteHasBeenReset();
    event tipSentBy(address tipserAddress);

    //Constructor_______________________________________________________________________________________________________________________________________________________

    //modifiers_________________________________________________________________________________________________________________________________________________________
    modifier currentWorkflowStatusMustIn(WorkflowStatus _mandatoryWorkflowStatus) {
        //require(currentWorkflowStatus == _mandatoryWorkflowStatus,string.concat("The current workflow status must be:", Strings.toString(uint(_mandatoryWorkflowStatus)), " but currently it is:", Strings.toString(uint(currentWorkflowStatus))));
        _;
    }

    modifier onlyRegisteredSender(){
        //require(voters[msg.sender].isRegistered, "You are not registered for submitting proposals or voting, sorry buddy !");
        _;
    }

    modifier onlyHasntVotedSender(){
        //require(!voters[msg.sender].hasVoted, "You have already voted, you little scamp !");
        _;
    }

    modifier mustHaveWinner(){
        require(headProposalIds.length > 0, unicode"Nobody voted or all votes are invalid. Boo democracy! long live monarchy!🤴");
        _;
    }


    //functions_________________________________________________________________________________________________________________________________________________________
    function addOneAdressToWhiteList(address _voterAddress) external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){ 
        require(_voterAddress != address(0),"Wrong address entered");
        require(!voters[_voterAddress].isRegistered,"Voter's address is already registered");

        /* L'electeur est ajouté à la whitelist de votants :
        - isRegistered : true
        - hasVoted : false
        - votedProposalId : 0
        - numberOfProposals : 0
        */
        voters[_voterAddress] = Voter(true,false,0,0);
        emit VoterRegistered(_voterAddress);
    }

    /*
    /// @notice Pour facilier l'ajout de plusieurs votants d'une traite, cette fonction permet d'ajouter un tableau de votants
    /// @dev J'ai commenté cette fonction car si je l'active, je dois mettre la fonction addOneAdressToWhiteList en public, ce qui genere plus de gas, 
    je prefere donc la commenter et la garder sous le coude si le besoin est réel
    /// @param Tableau d'adresses de votant
    function addArrayOfAddressToWhiteList(address[] calldata _voterAddresses) external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){
        for(uint i = 0; i < _voterAddresses.length; i++) {
            addOneAdressToWhiteList(_voterAddresses[i]);
        }   
    }
    */

    function startProposalsRegistration() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){
        //Ajout de la proposition : vote blanc
        proposals.push(Proposal("Vote blanc",0,address(0)));
        //Le vote blanc ne peut etre rajouté plusieurs fois car nous avons un modifier qui gère l'avancé du statut de vote dans un sens unique
        //Si une nouvelle session redémarre, Le tableau est supprimé et donc le vote blanc aussi.
        //Le vote blanc ici est comptabilité parmi les propositions et peut etre choisi comme vainqueur contrairement aux elections du gouvernements francais

        currentWorkflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,currentWorkflowStatus);
    }

    function addProposal(string calldata proposalDescription) external currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationStarted) onlyRegisteredSender {
        require(bytes(proposalDescription).length > 0, "Proposal description can't be empty");
        require(voters[msg.sender].numberOfProposals < 3, "Thank you for having so much creativity, you can only suggest 3 proposals maximum by voter");
        
        proposals.push(Proposal(proposalDescription,0,msg.sender));
        voters[msg.sender].numberOfProposals++;
        emit ProposalRegistered(proposals.length-1);
    }

    function endProposalsRegistration() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationStarted){
        currentWorkflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,currentWorkflowStatus);
    }

    function startVotingSession() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationEnded){
        currentWorkflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,currentWorkflowStatus);
    }

    function voteForProposalId(uint _proposalId) external currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionStarted) onlyRegisteredSender onlyHasntVotedSender{
        ballotArray.push(_proposalId);
        voters[msg.sender].votedProposalId = _proposalId;
        //voters[msg.sender].hasVoted = true;
        emit Voted (msg.sender, _proposalId);
    }

    function endVotingSession() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionStarted){
        currentWorkflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,currentWorkflowStatus);
    }

    function setVotesTallied() internal onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionEnded){
        currentWorkflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,currentWorkflowStatus);
    }

    function countingVotesAndSetWinner() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionEnded) {        
        uint _winnerProposalIdCounts;

        for(uint i = 0; i < ballotArray.length; i++) {
        
            //si l'id de la proposition n'existe pas alors le vote est nul et non comptabilisé
            if(ballotArray[i] >= proposals.length){
                break;
            }

            //_proposal est une reference vers l'espace storage de la proposition dans le tableau proposals en variable globale
            //donc reduction du cout de gas
            //J'ai besoin d'une reference car je veux modifier le nombre de voix de la variable en storage
            Proposal storage _proposal = proposals[ballotArray[i]];
            //comptage du vote
            _proposal.voteCount++;

            //Si la proposition dépouillée a le plus de voix parmi les propopositions
            //alors nous l'enregistrons comme seule proposition en tete en supprimant d'abord les propostions en tete précendentes 
            if(_proposal.voteCount > _winnerProposalIdCounts){
                delete headProposalIds;
                _winnerProposalIdCounts = _proposal.voteCount;
                
                //Je prefere enregistrer les id plutot que les proposals car moins couteux en gas 
                headProposalIds.push(ballotArray[i]);
            }
            //Si la proposition dépouillée a autant de voix que la proposition en tete nous l'ajoutons parmis les propostions en tete
            else if(_proposal.voteCount == _winnerProposalIdCounts)
            {
                //Je prefere enregistrer les id plutot que les proposals car moins couteux en gas 
                headProposalIds.push(ballotArray[i]);
            }
        }

        //A la fin du dépouillage, si 1 seule proposition en tete
        if(headProposalIds.length == 1){
            winningProposalId = headProposalIds[0];
            
            //Evenement envoyé au front pour annoncer la proposition vainqueure
            emit AndTheWinnerIs(winningProposalId);
        }
        //A la fin du dépouillage, si plusieurs propositions ex aequo
        else if(headProposalIds.length > 1){
            // En cas d'égalité, je tire au sort la proposition gagnante parmi les ex aequo
            winningProposalId = headProposalIds[uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, randomizerNonce))) % headProposalIds.length];
            randomizerNonce++;

            //Evenement envoyé au front pour annoncer la proposition vainqueure
            emit AndTheWinnerIs(winningProposalId);
        }
        //A la fin du dépouillage, s'il n'y aucun vote ou que des votes nuls, pas de proposition choisi
        //Le vote blanc est comptabilité comme un vote donc il peut gagner les elections !

        //Fin du comptage
        setVotesTallied();
    }

    function getWinner() external view currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied) mustHaveWinner returns(string memory description, uint voteCount){
        return(proposals[winningProposalId].description,proposals[winningProposalId].voteCount);
    }


    //Ameliorations_________________________________________________________________________________________________________________________________________________________
    
    /// @notice Supprime la session de vote et repasse le statut du vote à : "Enregistrement des votants" mais conserve l'état des votants actuel pour l'instant
    function resetAllVotes() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied){
        delete proposals;
        delete ballotArray;

        currentWorkflowStatus = WorkflowStatus.RegisteringVoters;
        delete headProposalIds;
        emit voteHasBeenReset();
    }

    /// @notice Remercie la proposition du vainqueur par un petit pourboire
    function tipTheWinner() external payable currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied) mustHaveWinner{
        require(msg.value > 0.01 ether,"The mimimum tip is 0.01 ether");
        require(proposals[winningProposalId].addressOfProposalPerson != msg.sender,"You are the winner ! Can't send to yourself");

        //@dev Le gagnant peut etre le vote blanc qui a son adresse à 0, on verifie donc si l'adresse n'est pas à 0
        require(proposals[winningProposalId].addressOfProposalPerson != address(0),"Address of the winner is invalid");

        (bool succes,) = payable(proposals[winningProposalId].addressOfProposalPerson).call{value:msg.value}("");
        require(succes, "Transfer failed");
        emit tipSentBy(msg.sender);
    }

}