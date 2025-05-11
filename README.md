# RentalAgreement.sol

Contrato de alquiler en blockchain. Con este contrato inteligente, podrá iniciar un contrato de alquiler entre propietario e inquilino.

ANTES DE IMPLEMENTAR

Para implementar correctamente, debe ingresar:

1. Dirección del propietario.
2. Dirección del inquilino.
3. Dirección del contrato del token (ej.: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F para USDT en la red principal de Poligon).
4. Monto de la renta mensual (ej.: 500 USDT = 500000000, ya que USDT usa 6 ceros).
5. Meses de garantía (ej.: 3, siguiendo el ejemplo anterior de 500 USDT, 3 x 500 = 1500, por lo que la garantía solicitada en este contrato será de 1500 USDT).
6. Años del contrato: indique la duración del contrato en años. Fecha límite de pago: (p. ej.: 10; esto significa que el inquilino tiene 10 días después del inicio del mes para pagar la renta).
7. Mes de inicio: (p. ej.: 5; esto significa que su contrato comienza considerando que el mes inicial del contrato es mayo).
   
DESPUÉS DE LA IMPLEMENTACIÓN (POR UNICA VEZ VEZ)

0. El reloj de arena del contrato inicia, startTime = block.timestamp (se toma cuando se inicia el contrato).
1. El primer paso, por parte del inquilino, consiste en depositar la garantía mediante la función "depositGuarantee". Sin embargo, aquí tendrá un paso adicional: debe aprobar el importe de la garantía a esta dirección del contrato (este paso no está explícito en este contrato; debe implementar la interfaz IERC20). Utilice la función "aprove"; aquí debe ingresar el importe a aprobar ("guaranteeAmount" y la "dirección del contrato"). Tras la aprobación, podrá ejecutar la función "depositGuarantee"). Ahora puede verificar la función "Garantía depositada" (debe ser verdadera) y, si llama a la función "SaldoGarantía", debería mostrar "ImporteGarantía" (saldo de la garantía = importe de la garantía).

DESPUÉS DE LA IMPLEMENTACIÓN (CADA MES)

1. INQUILINO:

Opción A) Llamar a la función "PayMonthlyRent". Siguiendo el ejemplo anterior, ingrese el importe 500 * 10 ** 6 (USDT usa 6 ceros) y realice la transacción. 
Opción B) Realizar una transferencia directa a la dirección del contrato y luego llamar a la función "RegisterDirectPayment" para ingresar el importe transferido (el contrato verificará que sea verdadera).

2. PROPIETARIO: Revisa tu billetera. Si el contrato no transfirió la renta mensual a tu billetera, significa que el inquilino no lo hizo. Por lo tanto, después de la "FECHA LÍMITE DE PAGO", puedes usar la función "CHECKMISSEDPAYMENT" y el contrato transferirá un mes de renta a tu billetera (siguiendo el ejemplo anterior, el monto de la garantía era de 1500 USDT; ahora el contrato transferirá 500 USDT a la dirección del propietario, por lo que el monto de la garantía actual será de 1000 USDT).
   
3. INQUILINO: Imagina que la FECHA LÍMITE DE PAGO es el 10 de junio y no pagaste antes de esa fecha, por lo que el contrato ya transfirió un mes de la garantía del depósito al propietario, pero ahora es 15 y tienes el dinero para pagar la renta. Puede seguir el paso 1 (opción A o B). La diferencia radica en que ahora el contrato detectará que falta un mes de garantía, por lo que utilizará este dinero para recuperar el importe de la garantía en lugar de transferirlo al propietario.
   
4. PROPIETARIO: El contrato puede almacenar el importe de la garantía más un mes de alquiler. Cualquier valor superior se considerará un "exceso", ya sea porque 1) el inquilino realizó una transferencia directa al contrato durante dos meses consecutivos sin usar la función "REGISTERDIRECTPAYMENT", 2) porque alguien realizó una transferencia accidental al contrato, o 3) porque el inquilino rompió algún elemento de la propiedad. Por lo tanto, el arrendador puede cargar este importe dentro del contrato inteligente para registrar la transacción. En cualquier caso, el arrendador tiene esta función para retirar cualquier excedente del contrato, pero nunca el importe de la garantía más un mes de alquiler, es decir, el contrato inteligente impide que el propietario pueda retirar tanto la garantia como un mes de alquiler.
   
AL FINALIZAR EL CONTRATO

INQUILINO: Al finalizar el contrato, el inquilino tendrá habilitada la función "ReturnGuarantee", la cual transferirá el importe de la garantía a su billetera.

P.D.: Es importante decir que este contrato no es una forma legal de cubrirse en un contrato de alquiler, por el momento no existe legislación al respecto, esto podría ser útil si prefieres eliminar intermediarios como agencias inmobiliarias, en este caso el monto de la garantía cubrirá al propietario por 1, 2, 3  meses (depende de como quieran acordar ambas partes) si el inquilino no paga a tiempo, sin embargo, ambas partes deben firmar un contrato legal que, además de los términos legales típicos, especifique la address, los términos y condiciones del contrato inteligente, y aclare que una vez que al fondo de garantía le quede un mes de alquiler restante (ej. la garantia son 3 meses, el inquilino no pago 2 meses), el contrato se rescinde y ese mes queda a favor del propietario como penalización.

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Rental Agreement on blockchain 
Using this smart contract you will be able to start a rental agreement between landlord and tenant

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

2. LANDLORD: check your wallet, if the contract didn't transfer the monthly rent to your wallet means that the tenant didn't do, so after the "PAYMENT DEADTHLINE" you can call the function "CHECKMISSEDPAYMENT" and the contract will transfer 1 month of rent to your wallet (following the previous example, the guarantee amount was 1.500 USDT, now the contract will transfer to the landlord address 500 USDT, so the current guarantee amount now will be 1.000 USDT)
3. TENANT: let's imagine that PAYMENT DEADTHLINE is june 10th and you didn't pay before that date, so the contract already transfered 1 month of the deposit guarantee to the landlord, but now is 15th and you have the money to pay the rent. you can follow the step 1 (either option A or option B), the difference is that now the contract will realise that 1 month of guarantee is missing, so will use this money to recover the guarantee amount instead of transfer to the landlord.
4. LANDLORD: the contract is able to store the guarantee amount plus 1 month of rent, any value above this will be an "excess", either because the tenant made direct transfer to the contract for two months in a row without calling the funcion "REGISTERDIRECTPAYMENT", or because somebody made an accidental transfer to the contract, or because the tenant broke something of the property, so the lanlord can charge this item inside of the smart contract in order to register the transaction. In any case, the landlord has this function to withdraw any excess of the contract, but never the guarantee amount plus one month of rent.

AFTER THE CONTRACT HAS FINISHED

TENANT: after the contract time reaches his end, the tenant will have the function "ReturnGuarantee" enabled to be called, which will transfer the guarantee amount to his wallet.

P.S.: Is important to say that this contract is not a legal way to cover yourself in a rental agreement, at the moment there is not legislation about this, This could be useful if you prefer to eliminate intermediaries such as real estate agencies, in this case the guarantee amount will cover the landlord for 1,2,3 months if the tenant doesn't pay on time (depends on the guarantee amount), However, both parties must sign a legal contract that, in addition to the typical legal terms, specifies the address, terms and conditions of the smart contract, and clarifies that once the guarantee fund has one month's rent remaining (ej. the guarantee amount is three months and the tenant didn't pay for two months), the contract is terminated and that month remains in favor of the landlord as a penalty. 
