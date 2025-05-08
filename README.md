# RentalAgreement.sol
Rental Agreement on blockchain 
Using this smart contracto you will be able to start a rental agreement between landlord and tenant

BEFORE DEPLOYING

To deploy correctly you have to input: 
1. landlord address. 
2. tenant address.
3. token contract address (eg: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F for USDT in poligon mainnet).
4. Monthly Rent amount (eg: 500 USDT = 500000000, because USDT use 6 zeros).
5. Guarantee months (eg: 3, following the previous example of 500 USDT, 3x500 = 1500, so the guarantee asked in this contract will be 1500 USDT).
6. Contract years: how long in years yo want this contract.
7. Payment deadthline: (eg: 10, this means the tenant have 10 days after the start of the month to pay the rent).
8. StartMonth: (eg: 5, this means your contract starts taking into account that the initial month of the contract is may).

AFTER DEPLOYING (ONE TIME)

0. Time is clicking, startTime = block.timestamp (taken when the contract has been launched).
1. Step number one is on the tenant side and is to deposit the guarantee using the "depositGuarantee" function, but here, you will have an extra step, you have to aprobe the guarantee amount to this contract address (this step is not explicit in this contract, you have to deploy the IERC20 interface)
Use the aprove function, here you have to input the amount to aprove "guaranteeAmount" and the "contract address", after aproving you will be able to execute the "depositGuarantee" function). 
2. Now you can check in "guarantee Deposited" function (should be true) and if you call "guaranteeBalance" function, should show the "guaranteeAmount" (guarantee balance  = guarantee amount).

AFTER DEPLOYING (EACH MONTH)

1.TENANT:
  Option A) call the function "PAYMONTHLYRENT", following the previous example, you input the amount 500 * 10 ** 6 (USDT use 6 zeros) and transact.
  Option B) make a direct transfer to the contract address and then call the function "REGISTERDIRECTPAYMENT" input the amount you transfered (the contract will verify this is true).
2. LANDLORD: check your wallet, if the contract didn't transfer the monthly rent to your wallet means that the tentant didn't do, so after the "PAYMENT DEADTHLINE" you can call the function "CHECKMISSEDPAYMENT" and the contract will transfer 1 month or rent to your wallet (following the previous example, the guarantee amount was 1.500 USDT, now the contract will transfer to the landlord address 500 USDT, so the current guarantee amount now will be 1.000 USDT)
3. TENANT: let's imagine that PAYMENT DEADTHLINE is june 10th and you didn't pay before that date, so the contract already transfered 1 month of the deposit guarantee to the landlord, but now is 15th and you have the money to pay the rent. you can follow the step 1 (either option A or option B), the difference is that now the contract will realise that 1 month of guarantee is missing, so will use this money to recover the guarantee amount instead of transfer to the landlord.
4. LANDLORD: the contract is able to store the guarantee amount plus 1 month of rent, any value above this will be an "excess", either because the tenant made direct transfer to the contract for two months in a row without calling the funcion "REGISTERDIRECTPAYMENT", or because somebody made an accidental transfer to the contract, or because the tenant broke something of the property, so the lanlord can charge this item inside of the smart contract in order to register the transaction. In any case, the landlord has this function to withdraw any excess of the contract, but never the guarantee amount plus one month of rent.

AFTER THE CONTRACT HAS FINISHED

TENANT: after the contract time reaches his end, the tenant will have this function enabled to be called, which will transfer the guarantee amount to his wallet.

