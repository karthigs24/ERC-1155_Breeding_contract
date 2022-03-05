// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GameNFTs is ERC1155, Ownable {
    using Strings for string;
    using SafeMath for uint256;

    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => string) customUri;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    event Birth(
        address owner,
        uint256 kittyId,
        uint256 totalSupply,
        uint256 dna,
        uint256 generation
    );

    event Breed(
        address owner,
        uint256 kittyId,
        uint256 momId,
        uint256 dadId,
        uint256 dna,
        uint256 generation
    );

    struct Kitty {
        uint256 dna;
        uint64 birthTime;
        uint32 id;
        string uri;
        uint32 momId;
        uint32 dadId;
        uint16 generation;
    }

    Kitty[] kitties;

    /**
     * @dev Require _msgSender() to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            creators[_id] == _msgSender(),
            "GameNFTs#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    /**
     * @dev Require _msgSender() to own more than 0 of the token id
     */
    modifier ownersOnly(uint256 _id) {
        require(
            balanceOf(_msgSender(), _id) > 0,
            "GameNFTs#ownersOnly: ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC1155("") {
        name = _name;
        symbol = _symbol;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "GameNFTs#uri: NONEXISTENT_TOKEN");
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return super.uri(_id);
        }
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     * @param _newURI New URI for all tokens
     */
    function setURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    /**
     * @dev Will update the base URI for the token
     * @param _tokenId The token to update. _msgSender() must be its creator.
     * @param _newURI New URI for the token.
     */
    function setCustomURI(uint256 _tokenId, string memory _newURI)
        public
        creatorOnly(_tokenId)
    {
        customUri[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    /**
     * @dev Creates a new token type and assigns _initialSupply to an address
     * NOTE: remove onlyOwner if you want third parties to create new tokens on
     *       your contract (which may change your IDs)
     * NOTE: The token id must be passed. This allows lazy creation of tokens or
     *       creating NFTs by setting the id's high bits with the method
     *       described in ERC1155 or to use ids representing values other than
     *       successive small integers. If you wish to create ids as successive
     *       small integers you can either subclass this class to count onchain
     *       or maintain the offchain cache of identifiers recommended in
     *       ERC1155 and calculate successive ids from that.
     * @param _initialOwner address of the first owner of the token
     * @param _id The id of the token to create (must not currenty exist).
     * @param _initialSupply amount to supply the first owner
     * @param _uri Optional URI for this token type
     * @param _data Data to pass if receiver is contract
     * @param _dna Dna to pass if receiver is contract
     * @param _generation Generation to pass if receiver is contract
     * @return The newly created token ID
     */
    function create(
        address _initialOwner,
        uint256 _id,
        uint256 _initialSupply,
        string memory _uri,
        bytes memory _data,
        uint256 _dna,
        uint256 _generation
    ) public onlyOwner returns (uint256) {
        Kitty memory newKitty = Kitty({
            dna: uint32(_dna),
            birthTime: uint64(block.timestamp),
            id: uint32(_id),
            uri: string(_uri),
            momId: uint32(_id),
            dadId: uint32(_id),
            generation: uint16(_generation)
        });

        kitties.push(newKitty);
        _id = kitties.length - 1;

        require(!_exists(_id), "token _id already exists");
        creators[_id] = _msgSender();

        if (bytes(_uri).length > 0) {
            customUri[_id] = _uri;
            emit URI(_uri, _id);
        }

        _mint(_initialOwner, _id, _initialSupply, _data);

        emit Birth(_initialOwner, _id, _initialSupply, _dna, _generation);

        tokenSupply[_id] = _initialSupply;
        return _id;
    }

    function breed(uint256 _momId, uint256 _dadId)
        public
        onlyOwner
        returns (uint256 newKittyId)
    {
        require(
            creators[_momId] == msg.sender && creators[_dadId] == msg.sender,
            "Should own both kitties before breeding."
        );

        uint256 newDna = _mixDna(kitties[_momId].dna, kitties[_dadId].dna);
        uint256 newGen = _calcGen(
            kitties[_momId].generation,
            kitties[_dadId].generation
        );
        uint256 newId = _calcId(kitties[_momId].id, kitties[_dadId].id);
        string memory newUri = (kitties[_momId].uri);

        newKittyId = create(
            msg.sender,
            newId,
            100,
            newUri,
            "0x00",
            newDna,
            newGen
        );

        emit Breed(msg.sender, newKittyId, _momId, _dadId, newDna, newGen);
    }

    // Alternating Mixing Pattern
    function _mixDna(uint256 _momDna, uint256 _dadDna)
        internal
        pure
        returns (uint256 newDna)
    {
        uint256 newDna1stQuarter = _momDna / 1000000000000;
        uint256 newDna2ndQuarter = (_dadDna / 100000000) % 10000;
        uint256 newDna3rdQuarter = (_momDna % 100000000) / 10000;
        uint256 newDna4thQuarter = _dadDna % 10000;

        newDna =
            (newDna1stQuarter * 1000000000000) +
            (newDna2ndQuarter * 100000000) +
            (newDna3rdQuarter * 10000) +
            newDna4thQuarter;
    }

    function _calcGen(uint256 _momGen, uint256 _dadGen)
        internal
        pure
        returns (uint256 newGen)
    {
        if (_momGen <= _dadGen) {
            newGen = _dadGen + 1;
        } else {
            newGen = _momGen + 1;
        }
    }

    function _calcId(uint256 _momId, uint256 _dadId)
        internal
        pure
        returns (uint256 newId)
    {
        if (_momId <= _dadId) {
            newId = _dadId + 1;
        } else {
            newId = _momId + 1;
        }
    }

    /**
     * @dev Mints some amount of tokens to an address
     * @param _to          Address of the future owner of the token
     * @param _id          Token ID to mint
     * @param _quantity    Amount of tokens to mint
     * @param _data        Data to pass if receiver is contract
     */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public virtual creatorOnly(_id) {
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id].add(_quantity);
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(
                creators[_id] == _msgSender(),
                "GameNFTs#batchMint: ONLY_CREATOR_ALLOWED"
            );
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id].add(quantity);
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }

    /**
     * @notice Burn _quantity of tokens of a given id from msg.sender
     * @dev This will not change the current issuance tracked in _supplyManagerAddr.
     * @param _id     Asset id to burn
     * @param _quantity The amount to be burn
     */
    function burn(uint256 _id, uint256 _quantity) public ownersOnly(_id) {
        _burn(_msgSender(), _id, _quantity);
        tokenSupply[_id] = tokenSupply[_id].sub(_quantity);
    }

    /**
     * @notice Burn _quantities of tokens of given ids from msg.sender
     * @dev This will not change the current issuance tracked in _supplyManagerAddr.
     * @param _ids     Asset id to burn
     * @param _quantities The amount to be burn
     */
    function batchBurn(uint256[] calldata _ids, uint256[] calldata _quantities)
        public
    {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(
                balanceOf(_msgSender(), _id) > 0,
                "GameNFTs#ownersOnly: ONLY_OWNERS_ALLOWED"
            );
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id].sub(quantity);
        }
        _burnBatch(msg.sender, _ids, _quantities);
    }

    /**
     * @dev Change the creator address for given tokens
     * @param _to   Address of the new creator
     * @param _ids  Array of Token IDs to change creator
     */
    function setCreator(address _to, uint256[] memory _ids) public {
        require(_to != address(0), "GameNFTs#setCreator: INVALID_ADDRESS.");
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            _setCreator(_to, id);
        }
    }

    /**
     * @dev Change the creator address for given token
     * @param _to   Address of the new creator
     * @param _id  Token IDs to change creator of
     */
    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
        creators[_id] = _to;
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }
}
