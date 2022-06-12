/*
::::::::::: :::::::::    :::           :::     :::        :::::::::: :::    :::     :::   ::: :::::::::: 
    :+:     :+:    :+: :+:+:         :+: :+:   :+:        :+:        :+:    :+:     :+:   :+: :+:        
    +:+     +:+    +:+   +:+        +:+   +:+  +:+        +:+         +:+  +:+       +:+ +:+  +:+        
    +#+     +#++:++#+    +#+       +#++:++#++: +#+        +#++:++#     +#++:+         +#++:   +#++:++#   
    +#+     +#+          +#+       +#+     +#+ +#+        +#+         +#+  +#+         +#+    +#+        
    #+#     #+#          #+#       #+#     #+# #+#        #+#        #+#    #+#        #+#    #+#        
    ###     ###        #######     ###     ### ########## ########## ###    ###        ###    ########## 
*/
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.14;

// @dev Permet rendre les fonctions choisies, exécutables que par le propriétaire du Smart contract
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// @dev Permet d'avoir des méthodes utilitaires supplémentaires pour manipuler des strings
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol";

// @notice Smart contract : Système de vote
contract Voting is Ownable{
    struct Voter {
        // @notice booleen permettant de savoir si le votant est inscrit
        bool isRegistered;

        // @notice booleen permettant de savoir si le votant a voté
        bool hasVoted;

        // @notice id de la proposition votée
        uint votedProposalId;

        // @notice nombre de proposition proposée
        uint numberOfProposals;
    }

    struct Proposal {
        // @notice description de la proposition
        string description;

        // @notice nombre de voix obtenue de la proposition
        uint voteCount;

        // @notice address de la personne qui a proposé la proposition
        address addressOfProposalPerson;
    }

    enum WorkflowStatus {
        RegisteringVoters, // @notice Etat : Enregistrement des votants
        ProposalsRegistrationStarted, // @notice Etat : Debut des propositions des votants
        ProposalsRegistrationEnded, // @notice Etat : Fin des propositions des votants
        VotingSessionStarted, // @notice Etat : Debut des votes
        VotingSessionEnded, // @notice Etat : Fin des votes
        VotesTallied // @notice Etat : Dépouillage effectué
    }

    //Pour eviter de trop alourdir le code pour de la fonction de calcul du vainqueur 
    //(et aussi parce que je suis épuisé par ma semaine de boulot),
    //je n'ai pas pas implémenté cette fonctionnalité optionnelle que souhaitais initialement ajouter.
    //Le vote sera par défaut réalisé sur la base d'une simple majoritée
    /*
    enum TypeOfMajority {
        SimpleMajority, //Simple majoritée : La proposition qui a le plus de vote gagne
        AbsoluteMajority //majorité absolue : La proposition qui a plus de 50% des voix gagne
    }
    */

    //Quorum necessaire pour qu'un vote soit valide
    enum TypeOfQuorum {
        quorum0, //Pas de votants minimum pour valider le vote 
        quorum25, //25% des votants doivent voter pour valider le vote
        quorum33, //33% des votants doivent voter pour valider le vote
        quorum50, //50% des votants doivent voter pour valider le vote
        quorum67 //67% des votants doivent voter pour valider le vote
    }

    //Variables_________________________________________________________________________________________________________________________________________________________
    
    // @notice mapping des votants ayant pour clé leur adresse
    // @dev le vote n'est pas secret. Le vote de chaque votant a une visibilité publique
    mapping (address => Voter) public voters;

    // @notice id de la proposition vainqueur 
    uint winningProposalId;

    // @notice Nonce permettant d'annonimiser 
    uint randomizerNonce; 

    // @notice Etat acctuel du vote : RegisteringVoters par défaut
    WorkflowStatus currentWorkflowStatus; 
    
    // @notice Gestion du quorum. quorum0 est la valeur par défaut
    // @dev Fonctionnalité supplémentaire
    TypeOfQuorum currentTypeOfQuorum;

    // @notice propositions en tete du dépouillement. J'ai besoin d'un tableau car je gère les propositions ex aequo
    uint[] headProposalIds;

    // @notice Urne de vote où sont enregistrées les id des propositions 
    // @dev Les bulletins dans l'urne sont visibles de tous. 
    uint[] public ballotArray;

    // @notice tableau d'adresses de tous les votants
    // @dev ce tableau n'est pas nécessaire pour les fonctionnalités de base.
    // Je l'ai rajouté pour les fonctionnalités : reset de l'election, qorum
    address[] addressOfvoters;
    
    // @notice tableau des propositions des votants
    Proposal[] public proposals;

    // @notice  Il permet d'avoir l'historique des propositions vainqueurs s'il y a plusieurs votes réasliés
    // @dev ce tableau n'est pas nécessaire pour les fonctionnalités de base.
    Proposal[] public allWinnerProposals; 

    //Events___________________________________________________________________________________________________________________________________________________________
    // @notice notifie lorsqu'un votant est ajouté
    event VoterRegistered(address voterAddress); 

    // @notice notifie lorsque le statut de l'ection est changé
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    // @notice notifie lorsqu'une proposition est ajoutée
    event ProposalRegistered(uint proposalId);

    // @notice notifie lorsqu'un vote a été effectué
    event Voted (address voter, uint proposalId);

    // @notice notifie lorsqu'une proposition est désignée vainqueur
    event AndTheWinnerIs(uint proposalId);

    // @notice notifie lorsque l'election a été réinitialisée (archivé)
    event voteHasBeenReset();

    // @notice notifie lorsqu'une personne a récompensé le vainqueur
    event tipSentBy(address tipserAddress);

    // @notice notifie lorsque le quorum n'a pas été atteint lors du dépouillement
    event quorumNotReached();

    // @notice notifie lorsque le statut du quorum a été modifié
    event quorumSetTo(TypeOfQuorum quorum);

    //Constructor_______________________________________________________________________________________________________________________________________________________

    //@dev décommenter ce constructeur pour accélerer les tests avec des votants déjà ajoutés
    // Et Passer la fonction addOneAdressToWhiteList à public pour pouvoir l'utiliser 
    /*
    constructor(){
        addOneAdressToWhiteList(address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4));
        addOneAdressToWhiteList(address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2));
        addOneAdressToWhiteList(address(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db));
    }
    */

    //modifiers_________________________________________________________________________________________________________________________________________________________
    modifier currentWorkflowStatusMustIn(WorkflowStatus _mandatoryWorkflowStatus) {
        require(currentWorkflowStatus == _mandatoryWorkflowStatus,string.concat("The current workflow status must be:", Strings.toString(uint(_mandatoryWorkflowStatus)), " but currently it is:", Strings.toString(uint(currentWorkflowStatus))));
        _;
    }

    modifier onlyRegisteredSender(){
        require(voters[msg.sender].isRegistered, "You are not registered for submitting proposals or voting, sorry buddy !");
        _;
    }

    modifier onlyHasntVotedSender(){
        require(!voters[msg.sender].hasVoted, "You have already voted, you little scamp !");
        _;
    }

    modifier mustHaveWinner(){
        require(headProposalIds.length > 0, unicode"Nobody voted or all votes are invalid or Quorum not reached. Boo democracy! Long live monarchy!🤴");
        _;
    }


    //functions_________________________________________________________________________________________________________________________________________________________
    // @notice ajoute un votant à la whitelist
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
        addressOfvoters.push(_voterAddress);
        emit VoterRegistered(_voterAddress);
    }

    /*
    // @notice Pour facilier l'ajout de plusieurs votants d'une traite, cette fonction permet d'ajouter un tableau de votants
    // @dev J'ai commenté cette fonction car si je l'active, je dois mettre la fonction addOneAdressToWhiteList en public, ce qui genere plus de gas, 
    je prefere donc la commenter et la garder sous le coude si le besoin est réel
    // @param Tableau d'adresses de votant
    function addArrayOfAddressToWhiteList(address[] calldata _voterAddresses) external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){
        for(uint i = 0; i < _voterAddresses.length; i++) {
            addOneAdressToWhiteList(_voterAddresses[i]);
        }   
    }
    */


    // @notice demarre la phase de propositions 
    function startProposalsRegistration() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){
        //Ajout de la proposition : vote blanc
        proposals.push(Proposal("Vote blanc",0,address(0)));
        //Le vote blanc ne peut etre rajouté plusieurs fois car nous avons un modifier qui gère l'avancé du statut de vote dans un sens unique
        //Si une nouvelle session redémarre, Le tableau est supprimé et donc le vote blanc aussi.
        //Le vote blanc ici est comptabilité parmi les propositions et peut etre désigné comme vainqueur contrairement aux elections du gouvernement francais !

        currentWorkflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,currentWorkflowStatus);
    }

    // @notice ajoute une proposition
    // @param description de la proposition
    function addProposal(string calldata _proposalDescription) external currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationStarted) onlyRegisteredSender {
        require(bytes(_proposalDescription).length > 0, "Proposal description can't be empty");
        require(voters[msg.sender].numberOfProposals < 3, "Thank you for having so much creativity, you can only suggest 3 proposals maximum by voter");
        
        proposals.push(Proposal(_proposalDescription,0,msg.sender));
        voters[msg.sender].numberOfProposals++;
        emit ProposalRegistered(proposals.length-1);
    }

    // @notice termine la phase de propositions 
    function endProposalsRegistration() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationStarted){
        currentWorkflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,currentWorkflowStatus);
    }

    // @notice demarre la phase de vote 
    function startVotingSession() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.ProposalsRegistrationEnded){
        currentWorkflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,currentWorkflowStatus);
    }

    // @notice prise en compte d'vote de votant
    // @param id de la proposition dans le tableau proposals
    // @dev j'ai fait le choix de ne pas modifier le voteCount des propositions dans le tableau proposal car nous ne n'avons pas encore dépouillé l'urne
    // ceci afin de ne pas influencer les futurs votants
    function voteForProposalId(uint _proposalId) external currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionStarted) onlyRegisteredSender onlyHasntVotedSender{
        ballotArray.push(_proposalId);
        voters[msg.sender].votedProposalId = _proposalId;
        voters[msg.sender].hasVoted = true;
        emit Voted (msg.sender, _proposalId);
    }

    // @notice termine la phase de vote 
    function endVotingSession() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionStarted){
        currentWorkflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,currentWorkflowStatus);
    }

    // @notice termine la phase de depouillement 
    function setVotesTallied() internal onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionEnded){
        currentWorkflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,currentWorkflowStatus);
    }

    // @notice Depouillement des bulletins de votes et désigne un vainqueur s'il y en a un
    // En cas d'égalité un tirage au sort est effectué entre les propositions ex aequo en tete
    // @dev fonction la plus complexe du smart contract. Accrochez-vous. 
    function countingVotesAndSetWinner() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotingSessionEnded) {        
        //Nombre de voix de la proposition en tete
        uint _winnerProposalIdCounts;

        //Quorum non atteint
        if(currentTypeOfQuorum == TypeOfQuorum.quorum25 && ballotArray.length < addressOfvoters.length*25/100
        || currentTypeOfQuorum == TypeOfQuorum.quorum33 && ballotArray.length < addressOfvoters.length*33/100
        || currentTypeOfQuorum == TypeOfQuorum.quorum50 && ballotArray.length < addressOfvoters.length*50/100
        || currentTypeOfQuorum == TypeOfQuorum.quorum67 && ballotArray.length < addressOfvoters.length*67/100){
            //Fin du vote sans dépouillement car le quorum n'a pas été atteint
            setVotesTallied();
            emit quorumNotReached();

            //On quitte la fonction car on ne depouille pas si le quorum n'est pas atteint
            return;
        }


        for(uint i = 0; i < ballotArray.length; i++) {
        
            //si l'id de la proposition n'existe pas alors le vote est nul et non comptabilisé
            if(ballotArray[i] >= proposals.length){
                //on dépouille le bulletin suivant directement
                continue;
            }

            //_proposal est une reference vers l'espace storage de la proposition dans le tableau proposals en variable globale
            //donc reduction du cout de gas
            // @dev J'ai besoin d'une reference car je veux modifier le nombre de voix de la variable en storage
            Proposal storage _proposal = proposals[ballotArray[i]];
            
            //incrémentation du nombre de vote pour cette proposition
            _proposal.voteCount++;

            //Si la proposition dépouillée a le plus de voix parmi les propopositions
            //alors nous l'enregistrons comme seule proposition en tete en supprimant d'abord les propositions en tete précendentes
            //Nous avons besoin d'un tableau car je gere les propositions ex aequo
            if(_proposal.voteCount > _winnerProposalIdCounts){
                delete headProposalIds;
                _winnerProposalIdCounts = _proposal.voteCount;
                
                //Je prefere enregistrer les id plutot que la struct Proposal car moins couteux en gas (je pense)
                headProposalIds.push(ballotArray[i]);
            }
            //Si la proposition dépouillée a autant de voix que la proposition en tete nous l'ajoutons parmi les propositions en tete
            else if(_proposal.voteCount == _winnerProposalIdCounts)
            {
                //Je prefere enregistrer les id plutot que la struct Proposal car moins couteux en gas (je pense)
                headProposalIds.push(ballotArray[i]);
            }
        }

        //A la fin du dépouillement, si 1 seule proposition en tete
        if(headProposalIds.length == 1){
            winningProposalId = headProposalIds[0];

            //sauvegarde pour avoir un historique des vainqueurs
            allWinnerProposals.push(proposals[winningProposalId]);
            
            //Evenement envoyé au front pour annoncer la proposition vainqueure
            emit AndTheWinnerIs(winningProposalId);
        }
        //A la fin du dépouillement, si plusieurs propositions ex aequo
        else if(headProposalIds.length > 1){
            //@dev En cas d'égalité, je tire au sort la proposition gagnante parmi les ex aequo
            //C'est la dure loi du hasard, comme une séance de tirs au but
            winningProposalId = headProposalIds[uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, randomizerNonce))) % headProposalIds.length];
            randomizerNonce++;

            //sauvegarde pour avoir un historique des vainqueurs
            allWinnerProposals.push(proposals[winningProposalId]);

            //Evenement envoyé au front pour annoncer la proposition vainqueure
            emit AndTheWinnerIs(winningProposalId);
        }
        //A la fin du dépouillement, s'il n'y aucun vote ou que des votes nuls, pas de proposition choisi
        //Le vote blanc est comptabilité comme un vote donc il peut gagner les elections !

        //Fin du comptage
        setVotesTallied();
    }

    //@notice retourne le vainqueur du vote
    //@returns proposition vainqeure et le nombre de voix obtenues
    function getWinner() external view currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied) mustHaveWinner returns(string memory _description, uint _voteCount){
        return(proposals[winningProposalId].description,proposals[winningProposalId].voteCount);
    }


    //Fonctionnalités supplémentaires______________________________________________________________________________________________________________________________________________________
    
    // @notice Supprime la session de vote terminée
    // repasse le statut du vote à : "Enregistrement des votants"
    function resetAllVotes() external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied){
        
        //Reset le mapping des votants enregistrés
        for(uint i = addressOfvoters.length - 1; i >= 0; i --){
            voters[addressOfvoters[i]].isRegistered = false;
            voters[addressOfvoters[i]].hasVoted = false;

            //@dev Je ne suis pas obligé de mettre à zéro cette valeur pour économiser le gas car si hasVoted = false, 
            //alors votedProposalId n'est pas prise en compte
            //si hasVoted = true, elle sera égale à l'id de la proposition
            //Pour ne pas perturber les personnes qui iraient consulter la valeur grace au getter public je prefere le reset à 0
            voters[addressOfvoters[i]].votedProposalId = 0; 
            voters[addressOfvoters[i]].numberOfProposals = 0;

            addressOfvoters.pop();
            
            //Si i == 0, alors je sors de ma boucle for car i-- de 0 ne fonctionne pas car i est un uint
            if(i==0){
                break;
            }
        }
        delete proposals;
        delete ballotArray;

        currentWorkflowStatus = WorkflowStatus.RegisteringVoters;
        currentTypeOfQuorum = TypeOfQuorum.quorum0;

        delete headProposalIds;
        emit voteHasBeenReset();
    }

    // @notice Remercie la proposition du vainqueur par un petit pourboire
    // @dev Les bulletins doivent etre comptés et un vainqeur désigné
    function tipTheWinner() external payable currentWorkflowStatusMustIn(WorkflowStatus.VotesTallied) mustHaveWinner{
        //@dev Pas de tips inférieur à 0.01 ether
        require(msg.value > 0.01 ether,"The mimimum tip is 0.01 ether");

        //@dev Pour éviter de se tipser soit meme
        require(proposals[winningProposalId].addressOfProposalPerson != msg.sender,"You are the winner ! Can't send to yourself");

        //@dev Le gagnant peut etre le vote blanc qui a son adresse à 0, on verifie donc si l'adresse n'est pas à 0
        require(proposals[winningProposalId].addressOfProposalPerson != address(0),"Address of the winner is invalid");

        (bool succes,) = payable(proposals[winningProposalId].addressOfProposalPerson).call{value:msg.value}("");
        require(succes, "Transfer failed");
        emit tipSentBy(msg.sender);
    }

    // @notice Parametrage du quorum possible pendant la phase d'enregistrement des votants uniquement
    // @param _quorum : la valeur du quorum à definir de type uint8 pour économiser du gas car la valeur max est 4.
    function setQuorumTo(uint8 _quorum) external onlyOwner currentWorkflowStatusMustIn(WorkflowStatus.RegisteringVoters){
        require(_quorum <= uint8(TypeOfQuorum.quorum67),"Invalid quorum value set");

        currentTypeOfQuorum = TypeOfQuorum(_quorum);

        emit quorumSetTo(currentTypeOfQuorum);
    }
}