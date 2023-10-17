package com.example.restservice;

import org.springframework.web.bind.annotation.*;
import java.math.BigInteger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.http.HttpService;
import org.web3j.model.P2PEth;
import org.web3j.crypto.Credentials;
import org.web3j.tx.gas.StaticGasProvider;
import org.web3j.tx.gas.DefaultGasProvider;
import org.web3j.tx.gas.ContractGasProvider;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.EthGetTransactionReceipt;
import org.web3j.protocol.core.methods.response.EthGetTransactionCount;
import org.web3j.protocol.core.methods.response.EthGetBalance;
import org.web3j.protocol.core.RemoteFunctionCall;
import org.web3j.protocol.core.DefaultBlockParameter;

@RestController
public class EthController {
    private static final Logger logger = LoggerFactory.getLogger(EthController.class);

    // Web3j initialization here
    Web3j web3j = Web3j.build(new HttpService("http://127.0.0.1:8545"));

    // Anvil test private key
    String privKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    Credentials credentials = Credentials.create(privKey);
    String contractAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
    ContractGasProvider contractGasProvider = new DefaultGasProvider();
    P2PEth sc = P2PEth.load(contractAddress, web3j, credentials, contractGasProvider);

    // Set gas price and gas limit
    BigInteger gasPrice = BigInteger.valueOf(20_000_000_000L); // 20 Gwei
    BigInteger gasLimit = BigInteger.valueOf(100_000); // 100,000

    @PostMapping("/users/deposit/{amount}")
    public String deposit(@PathVariable BigInteger amount/*@RequestParam BigInteger amount*/) {
        logger.info("Received Deposit request for amount: {}", amount);
        try {
            // Get the next available nonce
            EthGetTransactionCount ethGetTransactionCount = web3j.ethGetTransactionCount(credentials.getAddress(), DefaultBlockParameter.valueOf("latest")).send();
            BigInteger nonce = ethGetTransactionCount.getTransactionCount();

            logger.info("Nonce: {}", nonce);

            // Create transaction
            P2PEth contract = P2PEth.load(contractAddress, web3j, credentials, contractGasProvider/*new StaticGasProvider(gasPrice, gasLimit)*/);
            BigInteger weiValue = amount.multiply(BigInteger.valueOf(1000000000000000000L));
            TransactionReceipt transactionReceipt = contract.deposit(weiValue).send();

            // Get transaction hash
            String transactionHash = transactionReceipt.getTransactionHash();
            logger.info("Transaction hash: {}", transactionHash);

            // Wait for transaction to be mined
            EthGetTransactionReceipt ethGetTransactionReceipt = web3j.ethGetTransactionReceipt(transactionHash).send();
            while (ethGetTransactionReceipt.getTransactionReceipt().isEmpty()) {
                Thread.sleep(200);
                ethGetTransactionReceipt = web3j.ethGetTransactionReceipt(transactionHash).send();
            }

            // Get transaction receipt
            transactionReceipt = ethGetTransactionReceipt.getTransactionReceipt().get();
            logger.info("Transaction receipt: {}", transactionReceipt);

            // Get balance
            EthGetBalance ethGetBalance = web3j.ethGetBalance(credentials.getAddress(), DefaultBlockParameter.valueOf("latest")).send();
            BigInteger balance = ethGetBalance.getBalance();
            logger.info("Balance: {}", balance);
        } catch (Exception e) {
            logger.error("Error occurred: {}", e.getMessage());
            return "Deposit failed";
        }
        return "Deposit successful";
    }

    @GetMapping("/users/{address}/balance")
    public BigInteger getBalance(@PathVariable String address) {
        logger.info("Received Balance request for address: {}", address);

        try {
            RemoteFunctionCall<BigInteger> resp = sc.getBalance(address);
            return resp.send();
        } catch (Exception e) {
            logger.error("Error occurred: {}", e.getMessage());
            return BigInteger.valueOf(-1);
        }
    }
}