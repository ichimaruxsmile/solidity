// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DefiDeposit {
    mapping(address => uint256) private balances; // 用户存款余额
    mapping(address => uint256) private depositTimestamps; // 存款时间计算利率
    uint256 private constant INTEREST_RATE = 1; // 利率 (每秒1gas)
    
    /*
        event 事件
        1. 记录重要的合约状态变化
        2. 提供交易的历史记录
        3. 让前端应用能够"监听"这些事件，实时更新界面
        
        indexed 允许过滤和搜索事件
        1. 可以快速找到特定地址的所有存款记录
        2. 可以过滤特定用户的所有交易
        3. 最多可以给一个事件添加 3个 indexed 参数
    */
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 interest);
    event OwnerWithdraw(address indexed owner, uint256 amount, uint256 interest);

    /*
        modifier 修饰器
        用于在函数执行前检查条件
        require 用于确保条件满足，否则交易会回滚
        _ 表示被修饰的函数的其余代码(next)
    */
    // 检查用户是否有存款的修饰器
    modifier hasDeposit() {
        require(balances[msg.sender] > 0, "No deposit found");
        _;
    }

    // 计算利息的内部函数
    function calculateInterest(address user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - depositTimestamps[user];
        return timeElapsed * INTEREST_RATE;
    }

    // 存款函数
    function deposit() public payable {
        // 存款金额需要大于0
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        if (balances[msg.sender] == 0) {
            // 如果是首次存款，直接记录
            balances[msg.sender] = msg.value;
        } else {
            // 如果已有存款，先计算之前存款的利息
            balances[msg.sender] += msg.value + calculateInterest(msg.sender);
        }

        // 更新最新的存款时间以计算利息
        depositTimestamps[msg.sender] = block.timestamp;

        // 触发事件
        emit Deposit(msg.sender, msg.value);
    }

    // 提款函数
    function withdraw(uint256 _amount) public hasDeposit {
        // 取款金额需要大于0
        require(_amount > 0, "Withdraw amount must be greater than 0");
        
        // 计算当前可用利息
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalBalance = balances[msg.sender] + interest;
        
        // 检查用户余额是否足够
        require(totalBalance >= _amount, "Insufficient balance");
        
        // 更新余额和时间戳
        balances[msg.sender] = totalBalance - _amount;
        depositTimestamps[msg.sender] = block.timestamp;

        // 转账
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, _amount, interest);
    }

    // owner提取全部存款函数
    function ownerWithdraw() public hasDeposit {
        // 计算总金额（包括利息）
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalAmount = balances[msg.sender] + interest;
        
        // 清空余额
        balances[msg.sender] = 0;
        depositTimestamps[msg.sender] = 0;

        // 转账
        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");
        
        emit OwnerWithdraw(msg.sender, totalAmount, interest);
    }

    // 获取合约余额
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 获取用户当前总余额
    function getCurrentBalance(address _user) public view returns (uint256) {
        if (balances[_user] == 0) return 0;
        return balances[_user] + calculateInterest(_user);
    }

    /*
        特殊函数(回退函数), 处理所有其他情况

        receive() 
            1. 处理普通的ETH转账
            2. 当合约接收纯ETH转账时（没有调用任何具体函数）会触发
            3. 必须标记为 external 和 payable
            4. 不能有任何参数
            5. 不能返回任何值
            6. 每个合约只能有一个 receive 函数
        fallback() 
            1. 当调用的函数不存在时触发，或者当发送的数据不匹配任何函数时触发
            2. 必须标记为 external
            3. 可以标记为 payable 如果想要接收ETH
            4. 不能有参数
            5. 不能返回值
            6. 每个合约只能有一个 fallback 函数

        两者都调用 deposit() 函数来处理接收到的ETH
    */

    // 接收ETH的回退函数
    receive() external payable {
        deposit();
    }

    // 回退函数
    fallback() external payable {
        deposit();
    }
}