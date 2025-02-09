// SPDX-License-Identifier: MIT

// 声明使用的Solidity版本
pragma solidity ^0.8.0;

contract DefiDeposit {
    /*
        mapping HashMap
        记录键值对信息, 存储在区块链上. public 关键字会自动生成一个getter函数
        address 是用户的以太坊地址
        uint256 是无符号整数，用于存储大数值（适合存储 wei 单位的金额）
    */
    mapping(address => uint256) public balances; // 用 mapping 来记录用户(每个地址)的存款余额
    
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
    event Deposit(address indexed user, uint256 amount); // 存款事件
    event Withdraw(address indexed user, uint256 amount); // 提款事件
    event OwnerWithdraw(address indexed owner, uint256 amount); // owner提款事件

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

    /*
        function 函数
        public 表示任何人都可以调用这个函数
        payable 表示这个函数可以接收ETH
        view 表示函数只读取不修改状态

        相关变量:
        msg.value 是发送到合约的ETH数量
        msg.sender 是调用函数的地址
    */

    // 存款函数
    function deposit() public payable {
        // 存款金额需要大于0
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;

        // 触发事件
        emit Deposit(msg.sender, msg.value);
    }

    // 提款函数
    function withdraw(uint256 _amount) public hasDeposit {
        // 取款金额需要大于0
        require(_amount > 0, "Withdraw amount must be greater than 0");

        // 检查用户余额是否足够
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // 更新状态
        balances[msg.sender] -= _amount;

        // 进行转账
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");
        
        // 触发事件
        emit Withdraw(msg.sender, _amount);
    }

    // owner提取全部存款函数
    function ownerWithdraw() public hasDeposit {
        // 标记用户的所有存款
        uint256 amount = balances[msg.sender];
        
        // 更新状态
        balances[msg.sender] = 0;

        // 进行转账(全部)
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        // 触发事件
        emit OwnerWithdraw(msg.sender, amount);
    }

    // 获取合约余额
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 获取用户存款余额
    function getBalance(address _user) public view returns (uint256) {
        return balances[_user];
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