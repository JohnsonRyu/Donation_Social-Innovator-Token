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
    
    function add64(uint64 a, uint64 b) internal pure returns (uint64) {
        uint64 c = a + b;
        assert(c >= a);
        return c;
    }
}
// ----------------------------------------------------------------------------
// @Name ERC20 interface
// @Desc https://eips.ethereum.org/EIPS/eip-20
// ----------------------------------------------------------------------------
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
// ----------------------------------------------------------------------------
// @Name Ownable
// ----------------------------------------------------------------------------
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() { require(msg.sender == owner); _; }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
// ----------------------------------------------------------------------------
// @Name DateTime
// @Desc Timestamp to date
// ----------------------------------------------------------------------------
contract DateTime {
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    uint constant DAY_IN_SECONDS = 86400;
    uint constant YEAR_IN_SECONDS = 31536000;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint constant HOUR_IN_SECONDS = 3600;
    uint constant MINUTE_IN_SECONDS = 60;

    uint16 constant ORIGIN_YEAR = 1970;

    function isLeapYear(uint16 year) public pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function leapYearsBefore(uint year) public pure returns (uint) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function getDaysInMonth(uint8 month, uint16 year) public pure returns (uint8) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        }
        else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        }
        else if (isLeapYear(year)) {
            return 29;
        }
        else {
            return 28;
        }
    }

    function parseTimestamp(uint timestamp) internal pure returns (_DateTime dt) {
        uint secondsAccountedFor = 0;
        uint buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }

        // Hour
        dt.hour = getHour(timestamp);

        // Minute
        dt.minute = getMinute(timestamp);

        // Second
        dt.second = getSecond(timestamp);

        // Day of week.
        dt.weekday = getWeekday(timestamp);
    }

    function getYear(uint timestamp) public pure returns (uint16) {
        uint secondsAccountedFor = 0;
        uint16 year;
        uint numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            }
            else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }

    function getMonth(uint timestamp) public pure returns (uint8) {
        return parseTimestamp(timestamp).month;
    }

    function getDay(uint timestamp) public pure returns (uint8) {
        return parseTimestamp(timestamp).day;
    }

    function getHour(uint timestamp) public pure returns (uint8) {
        return uint8((timestamp / 60 / 60) % 24);
    }

    function getMinute(uint timestamp) public pure returns (uint8) {
        return uint8((timestamp / 60) % 60);
    }

    function getSecond(uint timestamp) public pure returns (uint8) {
        return uint8(timestamp % 60);
    }

    function getWeekday(uint timestamp) public pure returns (uint8) {
        return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
    }
}

// ----------------------------------------------------------------------------
// @Name RewardPool
// @Desc Contract Of Reward For Writing
// ----------------------------------------------------------------------------
contract RewardPool is Ownable {
    event TokenWithdrawEvent(address _to, uint256 _amount);
    event TokenRewardEvent(address _to, uint256 _amount, uint256 _timeStamp);
    event ChangeTokenCAEvent(address indexed previousCA, address indexed newCA);
    event ChangeRewardAmountEvent(uint256 indexed previousCA, uint256 indexed newCA);

    IERC20 private SIT_ADDRESS;
    uint256 private REWARD_AMOUNT;
    
    constructor() public {
        SIT_ADDRESS = IERC20(0x5288f80F4145035866aC4cB45a4D8DEa889ec827);
        REWARD_AMOUNT = 10 * 10**uint(18);
    }
    
    function withdrawToken(address _to, uint256 _amount) external onlyOwner {
        require(SIT_ADDRESS.transfer(_to, _amount));        
        emit TokenWithdrawEvent(_to, _amount);
    }

    function changeTokenAddress(IERC20 _tokenCA) external onlyOwner {
        require(_tokenCA != address(0));
        emit ChangeTokenCAEvent(SIT_ADDRESS, _tokenCA);
        SIT_ADDRESS = _tokenCA;
    }
    
    // _amount = amount x 10**decimals
    function changeRewardAmount(uint256 _amount) external onlyOwner {
        emit ChangeRewardAmountEvent(REWARD_AMOUNT, _amount);
        REWARD_AMOUNT = _amount;
    }

    function tokenTransfer() internal {
        require(SIT_ADDRESS.transfer(msg.sender, REWARD_AMOUNT));
        emit TokenRewardEvent(msg.sender, REWARD_AMOUNT, now);
    }
}
// ----------------------------------------------------------------------------
// @Name UserStore
// @Desc Contract Of Managing Userdata
// ----------------------------------------------------------------------------
contract UserStore is RewardPool, DateTime {
    using SafeMath for uint64;
    
    event NewMemberEvent(address _user, uint256 _userCount, uint256 _timestamp);

    struct UserData {
        uint64 userCount;
        uint8 rewardCount;
        uint256 lastTimeStamp;
        uint256[] userInconv;
    }
    
    mapping(address => UserData) private userStore;
    address[] private userAddress;

    uint64 private totalUserCount;
    uint8 private dailyRewardCount;

    constructor() public {
        // default daily reward 10
        dailyRewardCount = 10;
    }
    
    modifier canSignUp() { require(userStore[msg.sender].lastTimeStamp == 0); _; }
    modifier onlyMember() { require(userStore[msg.sender].lastTimeStamp != 0); _; }

    function changeDailyRewardCount(uint8 _rewardCount) external onlyOwner {        
        dailyRewardCount = _rewardCount;
    }
    
    function signUpUserAdmin(address[] _users) external onlyOwner {
        uint256 ui;
        
        for (ui = 0; ui < _users.length; ui++) {
            if(userStore[_users[ui]].lastTimeStamp == 0)
                insertId(_users[ui]);
        }
    }
    
    function checkUserID() internal canSignUp {
        // New member
        insertId(msg.sender);
    }
    
    function checkUserRewardCount() internal {
        checkResetRewardCount();
        
        if(userStore[msg.sender].rewardCount < dailyRewardCount) {
            tokenTransfer();
            IncreaseRewardCount();
        }
        
        changeLastTimeStamp();
    }

    function insertUserInconv(uint256 _inconvCount) internal {
        userStore[msg.sender].userInconv.push(_inconvCount);
    }
    
    function insertId(address _user) private {
        UserData memory _userData;        
        _userData.userCount = totalUserCount;
        _userData.lastTimeStamp = now;
        
        userStore[_user] = _userData;        
        totalUserCount = totalUserCount.add64(1);

        userAddress.push(_user); 
        
        emit NewMemberEvent(_user, totalUserCount, now);
    }
    
    function IncreaseRewardCount() private {
        userStore[msg.sender].rewardCount++;
    }
    
    function changeLastTimeStamp() private {
        userStore[msg.sender].lastTimeStamp = now;
    }
    
    function checkResetRewardCount() private {
        // UTC+09:00
        uint8 lastDay = getDay(userStore[msg.sender].lastTimeStamp + 32400);
        uint8 curDay = getDay(now + 32400);
        
        if(lastDay != curDay) {
            userStore[msg.sender].rewardCount = 0;
        } else {
            uint8 lastMonth = getMonth(userStore[msg.sender].lastTimeStamp + 32400);
            uint8 curMonth = getMonth(now + 32400);
            
            if(lastMonth != curMonth) {
                userStore[msg.sender].rewardCount = 0;
            }
        }
    }
    
    function getUserData(address _user) external view returns (uint64, uint256, uint8, uint256[]) {
        return (userStore[_user].userCount, userStore[_user].lastTimeStamp, userStore[_user].rewardCount, userStore[_user].userInconv);
    }
    function getUserCount(address _user) external view returns (uint64) { return (userStore[_user].userCount); }
    function getUserLastTimeStamp(address _user) external view returns (uint256) { return (userStore[_user].lastTimeStamp); }
    function getUserRewardCount(address _user) external view returns (uint8) { return (userStore[_user].rewardCount); }
    function getUserInconvNumber(address _user) external view returns (uint256[]) { return (userStore[_user].userInconv); }
    function getTotalUserCount() external view returns (uint64) { return (totalUserCount); }
    function getDailyRewardCount() external view returns (uint8) { return (dailyRewardCount); }
    function getTotalUserData() external view returns (address[]) { return (userAddress); }
}
// ----------------------------------------------------------------------------
// @Name InconvenienceStore
// @Desc Contract Of Managing InconvenienceData
// ----------------------------------------------------------------------------
contract InconvenienceStore {
    using SafeMath for uint256;
    
    event insertInconvenienceEvent (uint256 _idx, address _address, string _id, string _tag, uint256 _timestamp);
    
    struct Inconvenience {
        address owner;
        string id;
        string tag;
        string contents;
        uint256 timeStamp;
    }

    Inconvenience[] private inconveniences;
    uint256 internal inconvCount;

    function insertInconvenience(string _id, string _contents, string  _tag) internal {
        Inconvenience memory _inconvenience = Inconvenience({
            owner: msg.sender,
            id: _id,
            contents: _contents,
            tag: _tag,
            timeStamp: now
        });

        inconveniences.push(_inconvenience);        
        inconvCount = inconvCount.add(1);

        emit insertInconvenienceEvent(inconvCount, msg.sender, _id, _tag, now);
    }

    function getInconvenience(uint256 _inconvNum) external view returns (address, string, string, string, uint256) {
        return (inconveniences[_inconvNum].owner, inconveniences[_inconvNum].id, inconveniences[_inconvNum].tag, inconveniences[_inconvNum].contents, inconveniences[_inconvNum].timeStamp);
    }
    function getInconvAddress(uint256 _inconvNum) external view returns (address) { return (inconveniences[_inconvNum].owner); }
    function getInconvID(uint256 _inconvNum) external view returns (string) { return (inconveniences[_inconvNum].id); }
    function getInconvTag(uint256 _inconvNum) external view returns (string) { return (inconveniences[_inconvNum].tag); }
    function getInconvContents(uint256 _inconvNum) external view returns (string) { return (inconveniences[_inconvNum].contents); }
    function getInconvTimeStamp(uint256 _inconvNum) external view returns (uint256) { return (inconveniences[_inconvNum].timeStamp); }
    function getTotalInconvenienceCount() external view returns (uint256) { return inconvCount; }
}
// ----------------------------------------------------------------------------
// @Name Inconvenience
// @Desc Managing Contract
// @Creator Gi Hyeok Ryu (BlockSmith Developer)
// ----------------------------------------------------------------------------
contract Inconvenience is InconvenienceStore, UserStore {    
    function signUp() external canSignUp {
        checkUserID();
    }
    
    function postInconvenience(string _id, string _contents, string  _tag) external onlyMember {
        insertUserInconv(inconvCount);        
        insertInconvenience(_id, _contents, _tag);
        checkUserRewardCount();
    }
}