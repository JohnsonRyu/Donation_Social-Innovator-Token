pragma solidity ^0.4.24;
// ----------------------------------------------------------------------------
// @Name SafeMath
// @Desc Math operations with safety checks that throw on error
// https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
// ----------------------------------------------------------------------------
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
// ----------------------------------------------------------------------------
// @Name Address
// @Desc Utility library of inline functions on addresses
// https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/utils/Address.sol
// ----------------------------------------------------------------------------
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly { size := extcodesize(account) }
        return size > 0;
    }
}
// ----------------------------------------------------------------------------
// @Name IERC165
// ----------------------------------------------------------------------------
interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}
// ----------------------------------------------------------------------------
// @Name Ownable
// ----------------------------------------------------------------------------
contract Ownable {
    address public owner;
    address public marketAddress;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ChangeMarketAddress(address indexed previousMarket, address indexed newMarket);

    constructor() public {
        owner = msg.sender;
        marketAddress = 0x2975B5408766D40E715f223136Fa698a7378b0B8;
    }

    modifier onlyOwner() { require(msg.sender == owner); _; }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function changeMarketAddress(address _newMarket) external onlyOwner {
        require(_newMarket != address(0));
        emit ChangeMarketAddress(marketAddress, _newMarket);
        marketAddress = _newMarket;
    }
}
// ----------------------------------------------------------------------------
// @Name Pausable
// @Desc Base contract which allows children to implement an emergency stop mechanism.
// ----------------------------------------------------------------------------
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = true;

    modifier whenNotPaused() { require(!paused); _; }
    modifier whenPaused() { require(paused); _; }

    function pause() onlyOwner whenNotPaused external {
        paused = true;
        emit Pause();
    }

    function unpause() onlyOwner whenPaused external {
        paused = false;
        emit Unpause();
    }
}
// ----------------------------------------------------------------------------
// @Name ERC165
// ----------------------------------------------------------------------------
contract ERC165 is IERC165 {
    /**
     * 0x01ffc9a7 ===
     *     bytes4(keccak256('supportsInterface(bytes4)'))
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff);
        _supportedInterfaces[interfaceId] = true;
    }
}
// ----------------------------------------------------------------------------
// @Name IERC721
// ----------------------------------------------------------------------------
contract IERC721 is IERC165, Pausable {
    event Transfer(address from, address to, uint256 tokenId);
    event Approval(address owner, address approved, uint256 tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) public view returns (address _owner);

    function approve(address _to, uint256 _tokenId) public;
    function getApproved(uint256 _tokenId) public view returns (address _operator);

    function setApprovalForAll(address _operator, bool _approved) public;
    function isApprovedForAll(address _owner, address _operator) public view returns (bool);

    function transferFrom(address _from, address _to, uint256 _tokenId) public;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes _data) public;
}
// ----------------------------------------------------------------------------
// @Name IERC721Receiver
// ----------------------------------------------------------------------------
contract IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4);
}
// ----------------------------------------------------------------------------
// @Name ERC721
// ----------------------------------------------------------------------------
contract ERC721 is ERC165, IERC721 {
    using SafeMath for uint256;
    using Address for address;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    /*
     * 0x80ac58cd ===
     *     bytes4(keccak256('balanceOf(address)')) ^
     *     bytes4(keccak256('ownerOf(uint256)')) ^
     *     bytes4(keccak256('approve(address,uint256)')) ^
     *     bytes4(keccak256('getApproved(uint256)')) ^
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) ^
     *     bytes4(keccak256('isApprovedForAll(address,address)')) ^
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
     */
    mapping (uint256 => address) private _tokenOwner;
    mapping (uint256 => address) private _tokenApprovals;
    mapping (address => uint256) private _ownedTokensCount;
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    constructor () public {
        _registerInterface(_INTERFACE_ID_ERC721);
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0));
        return _ownedTokensCount[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0));
        return owner;
    }

    function approve(address to, uint256 tokenId) whenNotPaused public {
        address owner = ownerOf(tokenId);
        require(to != owner);
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId));
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address to, bool approved) whenNotPaused public {
        require(to != msg.sender);
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) whenNotPaused public {
        require(_isApprovedOrOwner(msg.sender, tokenId));

        _transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) whenNotPaused public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) whenNotPaused public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data));
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwner[tokenId];
        return owner != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0));
        require(!_exists(tokenId));

        _tokenOwner[tokenId] = to;
        _ownedTokensCount[to] = _ownedTokensCount[to].add(1);

        emit Transfer(address(0), to, tokenId);
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from);
        require(to != address(0));

        _clearApproval(tokenId);

        _ownedTokensCount[from] = _ownedTokensCount[from].sub(1);
        _ownedTokensCount[to] = _ownedTokensCount[to].add(1);

        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        internal returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }

        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        return (retval == _ERC721_RECEIVED);
    }

    function _clearApproval(uint256 tokenId) private {
        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
        }
    }
}
// ----------------------------------------------------------------------------
// @Name IERC721Enumerable
// ----------------------------------------------------------------------------
contract IERC721Enumerable is IERC721 {
    function totalSupply() public view returns (uint256 total);
    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256 _tokenId);
    
    function tokenByIndex(uint256 _index) public view returns (uint256);
}
// ----------------------------------------------------------------------------
// @Name ERC721Enumerable
// ----------------------------------------------------------------------------
contract ERC721Enumerable is ERC165, ERC721, IERC721Enumerable {
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    uint256[] private _allTokens;

    mapping(uint256 => uint256) private _allTokensIndex;
    /* 
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *      
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63  
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    constructor () public {
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balanceOf(owner));
        return _ownedTokens[owner][index];
    }

    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply());
        return _allTokens[index];
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        super._transferFrom(from, to, tokenId);

        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        super._mint(to, tokenId);

        _addTokenToOwnerEnumeration(to, tokenId);
        _addTokenToAllTokensEnumeration(tokenId);
    }

    function _tokensOfOwner(address owner) internal view returns (uint256[] storage) {
        return _ownedTokens[owner];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = _ownedTokens[from].length.sub(1);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex; 
        }

        _ownedTokens[from].length--;
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = _allTokens.length.sub(1);
        uint256 tokenIndex = _allTokensIndex[tokenId];
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;

        _allTokens.length--;
        _allTokensIndex[tokenId] = 0;
    }
}
// ----------------------------------------------------------------------------
// @Name IERC721Metadata
// ----------------------------------------------------------------------------
contract IERC721Metadata is IERC721 {
    function name() external view returns (string _name);
    function symbol() external view returns (string _symbol);
    function tokenURI(uint256 _tokenId) external view returns (string);
}
// ----------------------------------------------------------------------------
// @Name ERC721Metadata
// ----------------------------------------------------------------------------
contract ERC721Metadata is ERC165, ERC721, IERC721Metadata {
    string private _name;
    string private _symbol;

    mapping(uint256 => string) private _tokenURIs;
    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *     
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;

        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId));
        return _tokenURIs[tokenId];
    }

    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        require(_exists(tokenId));
        _tokenURIs[tokenId] = uri;
    }
}
// ----------------------------------------------------------------------------
// @Name ERC721Full
// ----------------------------------------------------------------------------
contract ERC721Full is ERC721, ERC721Enumerable, ERC721Metadata {
    constructor (string memory name, string memory symbol) public ERC721Metadata(name, symbol) {
    }
}
// ----------------------------------------------------------------------------
// @Name ERC20 interface
// ----------------------------------------------------------------------------
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
// ----------------------------------------------------------------------------
// @Project Inconvenience NFT
// @Desc Inconvenience NFT Can't Transfer
// @Creator Johnson Ryu (BlockSmith Developer)
// ----------------------------------------------------------------------------
contract InconvenienceNFT is ERC721Full {
    event TokenReceive(address _from, uint256 _amount);
    event TokenWithdrawEvent(address _to, uint256 _amount);
    event TokenMint(address _TokenOwner, uint256 _Level, string _NickName);
    event SetNewLevel(uint256 _level, uint256 _amount);
    event ChangeLevelUpCostEvent(uint256 _level, uint256 _amount);
    event ChangeNickNameCostEvent(uint256 _amount);
    event ChangeTokenCAEvent(address indexed _previousCA, address indexed _newCA);
        
    struct TokenData {
        uint256 level;
        string nickName;
        bool nickNameTicket;
    }

    mapping (uint256 => TokenData) private tokenDataList;
    uint256[] private LvUpCost;
    uint256 private nickNameCost;
    uint256 private SIT_DECIMALS;
    IERC20  private SIT_ADDRESS;

    constructor (string memory _name, string memory _symbol) public
    ERC721Full(_name, _symbol) {
        SIT_ADDRESS  = IERC20(0xc67357053ba575136fc110be2e8fdbd482601b1e);
        SIT_DECIMALS = SIT_ADDRESS.decimals();

        LvUpCost.push(1 * 10**uint(SIT_DECIMALS));
        LvUpCost.push(100 * 10**uint(SIT_DECIMALS));
        LvUpCost.push(300 * 10**uint(SIT_DECIMALS));
        LvUpCost.push(500 * 10**uint(SIT_DECIMALS));
        LvUpCost.push(1000 * 10**uint(SIT_DECIMALS));

        nickNameCost = 100 * 10**uint(SIT_DECIMALS);
    }

    modifier canMint() { require(balanceOf(msg.sender) == 0); _; }
    modifier onlyMember() { require(balanceOf(msg.sender) != 0); _; }

    function mintUniqueToken(string nickName) external canMint {
        // mint NFT
        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);

        TokenData memory newTokenData = TokenData({
            level : 0,
            nickName : nickName,
            nickNameTicket : false
        });

        tokenDataList[tokenId] = newTokenData;
        emit TokenMint(msg.sender, tokenDataList[tokenId].level, tokenDataList[tokenId].nickName);
    }

    function levelUp() external onlyMember {
        uint256 senderTokenID = tokenOfOwnerByIndex(msg.sender, 0);
        
        require(LvUpCost.length > tokenDataList[senderTokenID].level);
        require(checkAllowedAmount() >= LvUpCost[tokenDataList[senderTokenID].level]);

        tokenTransferFrom(LvUpCost[tokenDataList[senderTokenID].level]);
        tokenDataList[senderTokenID].level++;
    }

    function buyChangeNickName() external onlyMember {
        uint256 senderTokenID = tokenOfOwnerByIndex(msg.sender, 0);
        //User already have ticket
        require(tokenDataList[senderTokenID].nickNameTicket == false);
        // Check user NFT Level
        require(checkAllowedAmount() >= nickNameCost);
        
        tokenTransferFrom(nickNameCost);
        tokenDataList[senderTokenID].nickNameTicket = true;
    }

    function changeNickName(string _nickName) external onlyMember {
        uint256 senderTokenID = tokenOfOwnerByIndex(msg.sender, 0);
        require(tokenDataList[senderTokenID].nickNameTicket == true);
        
        tokenDataList[senderTokenID].nickName = _nickName;
        tokenDataList[senderTokenID].nickNameTicket = false;
    }

    function changeTokenAddress(IERC20 _tokenCA) external onlyOwner {
        require(_tokenCA != address(0));
        emit ChangeTokenCAEvent(SIT_ADDRESS, _tokenCA);
        SIT_ADDRESS = _tokenCA;
    }

    function withdrawToken(address _to, uint256 _amount) external onlyOwner {
        require(SIT_ADDRESS.transfer(_to, _amount));        
        emit TokenWithdrawEvent(_to, _amount);
    }

    function setNewLevel(uint256 _newLevel, uint256 _amount) external onlyOwner {
        require(LvUpCost.length + 1 == _newLevel);
        LvUpCost.push(_amount);
        emit SetNewLevel(_newLevel, _amount);
    }

    function changeLvUpCost(uint256 _level, uint256 _amount) external onlyOwner {
        LvUpCost[_level] = _amount;
        emit ChangeLevelUpCostEvent(_level, _amount);
    }
    
    function changeNickNameCost(uint256 _amount) external onlyOwner {
        nickNameCost = _amount;
        emit ChangeNickNameCostEvent(_amount);
    }

    function checkAllowedAmount() private view returns(uint256) {
        uint256 allowed = SIT_ADDRESS.allowance(msg.sender, address(this));
        return allowed;
    }

    function tokenTransferFrom(uint256 _amount) private {
        require(SIT_ADDRESS.transferFrom(msg.sender, marketAddress, _amount));
        emit TokenReceive(msg.sender, _amount);
    }

    function getUserLV(address _user) external view returns (uint256) {
        uint256 senderTokenID = tokenOfOwnerByIndex(_user, 0);        
        return tokenDataList[senderTokenID].level; 
    }

    function getUserNickName(address _user) external view returns (string) {
        uint256 senderTokenID = tokenOfOwnerByIndex(_user, 0);        
        return tokenDataList[senderTokenID].nickName; 
    }

    function getUserLVUpCost(address _user) external view returns (uint256) { 
        uint256 senderTokenID = tokenOfOwnerByIndex(_user, 0);
        return  LvUpCost[tokenDataList[senderTokenID].level];
    }
}