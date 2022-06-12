# TP1 Alex YE
TP1 Alex YE 
Promo Ropsten : Développeur

Ce projet est le 1er TP à rendre pour la Promo Ropsten : Développeur.

Fonctionnalités de bases :
* L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
* L'administrateur du vote commence la session d'enregistrement de la proposition.
* Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
* L'administrateur de vote met fin à la session d'enregistrement des propositions.
* L'administrateur du vote commence la session de vote.
* Les électeurs inscrits votent pour leur proposition préférée.
* L'administrateur du vote met fin à la session de vote.
* L'administrateur du vote comptabilise les votes.
* Tout le monde peut vérifier les derniers détails de la proposition gagnante.


Fonctionnalités supplémentaires :
* Le vote blanc est une proposition comme une autre. Elle peut etre désignée vainqueure. Vive la démocratie !
* Un bulletin de vote ayant pour n° de propostion inconnu est considéré comme un bulletin nul. Un votant peut tout à fait voter une proposition inexistante, son bulletin ne sera pas pris en compte.
* En cas d'égalité encore plusieurs propositions, un tirage au sort est effectué parmi les propositions ex aequo en tete à la suite du dépouillement
* Un qorum peut etre paramétré pendant la phase d'enregistrement. Si le quorum n'est pas atteint lors de la phase de dépouillement alors le dépouillement n'aura pas lieu
* Plusieurs session de vote peuvent avoir lieu. Le systene peut etre ré-initialisé.
* Le vainqueur d'une session sera conservé dans un tableau d'archive des vainqueurs 
* Limitation du nombre de propostions à 3 par votant
* Possiblité de récompenser le vainqueur en lui envoyant des ethers


## License

The TP1 Alex YE (i.e. all code outside of the `cmd` directory) is licensed under the
[GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.en.html),
also included in our repository in the `COPYING.LESSER` file.
