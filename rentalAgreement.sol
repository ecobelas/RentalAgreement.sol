// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RentalAgreement {
    // Direcciones de las partes
    address public landlord;
    address public tenant;
    IERC20 public usdtToken;

    // Parámetros del contrato (personalizables)
    uint256 public monthlyRent; // Monto del alquiler mensual en USDT
    uint256 public guaranteeAmount; // Monto de la garantía (monthlyRent * guaranteeMonths)
    uint256 public contractDuration; // Duración del contrato en segundos
    uint256 public paymentDeadline; // Plazo de pago en días

    // Estado del contrato
    uint256 public startTime; // Timestamp de inicio
    uint256 private contractEndTimestamp; // Timestamp de fin (interno)
    uint256 public guaranteeBalance;
    bool public guaranteeDeposited;
    mapping(uint256 => bool) public monthPaid; // Índice: mes relativo al inicio
    mapping(uint256 => uint256) public monthPaidAmount; // Monto pagado por mes

    // Días por mes para cada año (0-based: mes 0 = enero, mes 1 = febrero, etc.)
    uint256[][] private daysInMonth; // daysInMonth[year][month]
    uint256 private startMonth; // Mes de inicio (1 = enero, 4 = abril, etc.)
    uint256 private contractYears; // Número de años del contrato
    uint256 private currentYear; // Ano inicial del contrato

    // Estructura para representar una fecha
    struct Date {
        uint256 year;
        uint256 month;
        uint256 day;
    }

    // Eventos
    event GuaranteeDeposited(address indexed tenant, uint256 amount);
    event MonthlyPayment(address indexed tenant, uint256 month, uint256 amount);
    event GuaranteeWithdrawn(address indexed landlord, uint256 amount, uint256 month);
    event GuaranteeReturned(address indexed tenant, uint256 amount);
    event PaymentMissed(address indexed tenant, uint256 month);
    event DirectPaymentRegistered(address indexed tenant, uint256 month, uint256 amount);
    event GuaranteeRestored(address indexed tenant, uint256 month, uint256 amount);
    event ExcessRefunded(address indexed tenant, uint256 month, uint256 amount);

    // Modificadores
    modifier onlyLandlord() {
        require(msg.sender == landlord, "Solo el locador puede llamar a esta funcion");
        _;
    }

    modifier onlyTenant() {
        require(msg.sender == tenant, "Solo el locatario puede llamar a esta funcion");
        _;
    }

    modifier contractActive() {
        require(block.timestamp >= startTime, "Contrato no iniciado");
        require(block.timestamp <= contractEndTimestamp, "Contrato finalizado");
        _;
    }

    constructor(
        address _landlord,
        address _tenant,
        address _usdtToken,
        uint256 _monthlyRent,
        uint256 _guaranteeMonths,
        uint256 _contractYears,
        uint256 _paymentDeadline,
        uint256 _startMonth,
        uint256 _currentYear
    ) {
        require(_monthlyRent > 0, "El alquiler mensual debe ser mayor a cero");
        require(_guaranteeMonths > 0, "La garantia debe ser al menos 1 mes");
        require(_contractYears > 0, "La duracion debe ser al menos 1 ano");
        require(_paymentDeadline > 0, "El plazo de pago debe ser mayor a cero");
        require(_startMonth >= 1 && _startMonth <= 12, "Mes de inicio invalido");
        require(_currentYear >= 2020 && _currentYear <= 2100, "Ano actual invalido");

        landlord = _landlord;
        tenant = _tenant;
        usdtToken = IERC20(_usdtToken);
        monthlyRent = _monthlyRent;
        guaranteeAmount = _monthlyRent * _guaranteeMonths;
        contractYears = _contractYears;
        paymentDeadline = _paymentDeadline;
        startTime = block.timestamp;
        startMonth = _startMonth;
        currentYear = _currentYear;

        // Calcular la duración precisa del contrato considerando años bisiestos
        uint256 totalDays = 0;
        for (uint256 year = 0; year < _contractYears; year++) {
            totalDays += isLeapYear(_currentYear + year) ? 366 : 365;
        }
        contractDuration = totalDays * 1 days;
        contractEndTimestamp = startTime + contractDuration;

        // Inicializar los días por mes para cada año
        daysInMonth = new uint256[][](_contractYears);
        for (uint256 year = 0; year < _contractYears; year++) {
            daysInMonth[year] = new uint256[](12);
            daysInMonth[year][0] = 31; // Enero
            daysInMonth[year][1] = isLeapYear(_currentYear + year) ? 29 : 28; // Febrero
            daysInMonth[year][2] = 31; // Marzo
            daysInMonth[year][3] = 30; // Abril
            daysInMonth[year][4] = 31; // Mayo
            daysInMonth[year][5] = 30; // Junio
            daysInMonth[year][6] = 31; // Julio
            daysInMonth[year][7] = 31; // Agosto
            daysInMonth[year][8] = 30; // Septiembre
            daysInMonth[year][9] = 31; // Octubre
            daysInMonth[year][10] = 30; // Noviembre
            daysInMonth[year][11] = 31; // Diciembre
        }
    }

    // Función para determinar si un año es bisiesto
    function isLeapYear(uint256 year) internal pure returns (bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }

    // Función auxiliar para convertir un timestamp a una fecha
    function timestampToDate(uint256 timestamp) internal view returns (Date memory) {
        require(timestamp >= startTime, "Timestamp anterior al inicio");
        uint256 timeElapsed = timestamp - startTime;
        uint256 year = 0;
        uint256 month = 0; // Mes relativo al contrato
        uint256 totalDays = 0;

        // Calcular el año
        while (timeElapsed >= 365 days && year < contractYears - 1) {
            uint256 daysInYear = isLeapYear(currentYear + year) ? 366 : 365;
            if (timeElapsed < daysInYear * 1 days) break;
            timeElapsed -= daysInYear * 1 days;
            year++;
        }

        // Calcular el mes relativo
        while (timeElapsed >= 1 days) {
            uint256 calendarMonth = ((startMonth - 1 + month) % 12) + 1;
            uint256 daysInCurrentMonth = getDaysInMonth(year, calendarMonth);
            if (timeElapsed < daysInCurrentMonth * 1 days) break;
            timeElapsed -= daysInCurrentMonth * 1 days;
            totalDays += daysInCurrentMonth;
            month++;
            if (month % 12 == 0 && year < contractYears - 1) {
                year++;
            }
        }

        // Calcular el día
        uint256 day = timeElapsed / 1 days + 1; // Día del mes (1-based)
        uint256 finalCalendarMonth = ((startMonth - 1 + month) % 12) + 1;

        return Date({
            year: currentYear + year,
            month: finalCalendarMonth,
            day: day
        });
    }

    // Función para obtener la fecha de fin del contrato
    function getContractEndTime() public view returns (Date memory) {
        return timestampToDate(contractEndTimestamp);
    }

    // Función para obtener los días en un mes de un año específico
    function getDaysInMonth(uint256 year, uint256 month) internal view returns (uint256) {
        require(year < contractYears, "Ano fuera del contrato");
        require(month >= 1 && month <= 12, "Mes invalido");
        return daysInMonth[year][month - 1];
    }

    // Función para calcular el mes y año actuales
    function currentMonthAndYear() public view returns (uint256 year, uint256 month) {
        if (block.timestamp < startTime) return (0, 0);
        uint256 timeElapsed = block.timestamp - startTime;
        year = 0;
        month = 0; // Mes relativo al contrato
        uint256 totalDays = 0;

        // Calcular el año actual
        while (timeElapsed >= 365 days && year < contractYears - 1) {
            uint256 daysInYear = isLeapYear(currentYear + year) ? 366 : 365;
            if (timeElapsed < daysInYear * 1 days) break;
            timeElapsed -= daysInYear * 1 days;
            year++;
        }

        // Calcular el mes relativo al contrato
        while (timeElapsed >= 1 days) {
            uint256 calendarMonth = ((startMonth - 1 + month) % 12) + 1;
            uint256 daysInCurrentMonth = getDaysInMonth(year, calendarMonth);
            if (timeElapsed < daysInCurrentMonth * 1 days) break;
            timeElapsed -= daysInCurrentMonth * 1 days;
            totalDays += daysInCurrentMonth;
            month++;
            if (month % 12 == 0 && year < contractYears - 1) {
                year++;
            }
        }

        // Convertir el mes relativo al mes del calendario
        month = ((startMonth - 1 + month) % 12) + 1;
        return (year, month);
    }

    // Función interna para calcular el timestamp de inicio de un mes
    function getMonthStartTimestamp(uint256 year, uint256 month) internal view returns (uint256) {
        uint256 totalDays = 0;
        for (uint256 y = 0; y < year; y++) {
            for (uint256 m = 1; m <= 12; m++) {
                totalDays += getDaysInMonth(y, m);
            }
        }
        for (uint256 m = 0; m < month; m++) {
            uint256 calendarMonth = ((startMonth - 1 + m) % 12) + 1;
            totalDays += getDaysInMonth(year, calendarMonth);
        }
        return startTime + (totalDays * 1 days);
    }

    // Función pública para obtener la fecha de inicio de un mes
    function getMonthStart(uint256 year, uint256 month) public view returns (Date memory) {
        return timestampToDate(getMonthStartTimestamp(year, month));
    }

    // Función interna para calcular el timestamp de fin de un mes
    function getMonthEndTimestamp(uint256 year, uint256 month) internal view returns (uint256) {
        uint256 totalDays = 0;
        for (uint256 y = 0; y < year; y++) {
            for (uint256 m = 1; m <= 12; m++) {
                totalDays += getDaysInMonth(y, m);
            }
        }
        for (uint256 m = 0; m <= month; m++) {
            uint256 calendarMonth = ((startMonth - 1 + m) % 12) + 1;
            totalDays += getDaysInMonth(year, calendarMonth);
        }
        return startTime + (totalDays * 1 days) - 1;
    }

    // Función pública para obtener la fecha de fin de un mes
    function getMonthEnd(uint256 year, uint256 month) public view returns (Date memory) {
        return timestampToDate(getMonthEndTimestamp(year, month));
    }

    // Función interna para calcular el timestamp del plazo de pago
    function getPaymentDeadlineTimestamp(uint256 year, uint256 month) internal view returns (uint256) {
        return getMonthStartTimestamp(year, month) + paymentDeadline;
    }

    // Función pública para obtener la fecha del plazo de pago
    function getPaymentDeadline(uint256 year, uint256 month) public view returns (Date memory) {
        return timestampToDate(getPaymentDeadlineTimestamp(year, month));
    }

    // Función para depositar la garantía
    function depositGuarantee() external onlyTenant {
        require(!guaranteeDeposited, "Garantia ya depositada");
        require(usdtToken.balanceOf(msg.sender) >= guaranteeAmount, "Saldo insuficiente");
        require(usdtToken.allowance(msg.sender, address(this)) >= guaranteeAmount, "Aprobacion insuficiente");

        usdtToken.transferFrom(msg.sender, address(this), guaranteeAmount);
        guaranteeBalance = guaranteeAmount;
        guaranteeDeposited = true;

        emit GuaranteeDeposited(msg.sender, guaranteeAmount);
    }

    // Función para pagar el alquiler mensual
    function payMonthlyRent(uint256 amount) external onlyTenant contractActive {
        require(guaranteeDeposited, "Garantia no depositada");
        (uint256 year, uint256 month) = currentMonthAndYear();
        uint256 relativeYear = year; // Almacenar el año retornado
        uint256 monthIndex = relativeYear * 12 + (month - startMonth + 1 + (month < startMonth ? 12 : 0));
        require(!monthPaid[monthIndex], "Mes ya pagado");
        require(amount > 0, "Monto debe ser mayor a cero");
        require(usdtToken.balanceOf(msg.sender) >= amount, "Saldo insuficiente");
        require(usdtToken.allowance(msg.sender, address(this)) >= amount, "Aprobacion insuficiente");

        usdtToken.transferFrom(msg.sender, address(this), amount);
        monthPaidAmount[monthIndex] += amount;

        if (monthPaidAmount[monthIndex] >= monthlyRent) {
            monthPaid[monthIndex] = true;
            uint256 amountUsed = monthlyRent;
            uint256 excess = monthPaidAmount[monthIndex] - monthlyRent;

            if (guaranteeBalance < guaranteeAmount) {
                guaranteeBalance += monthlyRent;
                emit GuaranteeRestored(msg.sender, monthIndex, monthlyRent);
            } else {
                usdtToken.transfer(landlord, amountUsed);
                emit MonthlyPayment(msg.sender, monthIndex, amountUsed);
            }

            if (excess > 0) {
                usdtToken.transfer(tenant, excess);
                emit ExcessRefunded(tenant, monthIndex, excess);
            }
        } else {
            emit MonthlyPayment(msg.sender, monthIndex, amount);
        }
    }

    // Función para registrar una transferencia directa
    function registerDirectPayment(uint256 amount) external onlyTenant contractActive {
        require(guaranteeDeposited, "Garantia no depositada");
        (uint256 year, uint256 month) = currentMonthAndYear();
        uint256 relativeYear = year; // Almacenar el año retornado
        uint256 monthIndex = relativeYear * 12 + (month - startMonth + 1 + (month < startMonth ? 12 : 0));
        require(!monthPaid[monthIndex], "Mes ya pagado");
        require(amount > 0, "Monto debe ser mayor a cero");
        require(usdtToken.balanceOf(address(this)) >= guaranteeBalance + monthPaidAmount[monthIndex] + amount, "Fondos insuficientes en el contrato");

        monthPaidAmount[monthIndex] += amount;

        if (monthPaidAmount[monthIndex] >= monthlyRent) {
            monthPaid[monthIndex] = true;
            uint256 amountUsed = monthlyRent;
            uint256 excess = monthPaidAmount[monthIndex] - monthlyRent;

            if (guaranteeBalance < guaranteeAmount) {
                guaranteeBalance += monthlyRent;
                emit GuaranteeRestored(msg.sender, monthIndex, monthlyRent);
            } else {
                usdtToken.transfer(landlord, amountUsed);
                emit DirectPaymentRegistered(msg.sender, monthIndex, amountUsed);
            }

            if (excess > 0) {
                usdtToken.transfer(tenant, excess);
                emit ExcessRefunded(tenant, monthIndex, excess);
            }
        } else {
            emit DirectPaymentRegistered(msg.sender, monthIndex, amount);
        }
    }

    // Función para verificar pagos no realizados
    function checkMissedPayment(uint256 year, uint256 month) external onlyLandlord contractActive {
        require(guaranteeDeposited, "Garantia no depositada");
        (uint256 relativeYear, uint256 currentMonth) = currentMonthAndYear();
        require(year == relativeYear && month == currentMonth, "Mes invalido");
        uint256 monthIndex = relativeYear * 12 + (month - startMonth + 1 + (month < startMonth ? 12 : 0));
        require(!monthPaid[monthIndex], "Mes ya pagado");
        uint256 deadlineTimestamp = getPaymentDeadlineTimestamp(year, month);
        require(block.timestamp >= deadlineTimestamp, "Plazo no vencido");

        uint256 amountOwed = monthlyRent - monthPaidAmount[monthIndex];
        require(guaranteeBalance >= amountOwed, "Garantia insuficiente");
        guaranteeBalance -= amountOwed;
        usdtToken.transfer(landlord, amountOwed);

        emit GuaranteeWithdrawn(landlord, amountOwed, monthIndex);
        emit PaymentMissed(tenant, monthIndex);
    }

    // Función para devolver la garantía
    function returnGuarantee() external onlyTenant {
        require(guaranteeDeposited, "Garantia no depositada");
        require(block.timestamp >= contractEndTimestamp, "Contrato no finalizado");
        require(guaranteeBalance > 0, "Garantia ya retirada");

        uint256 amountToReturn = guaranteeBalance;
        guaranteeBalance = 0;
        usdtToken.transfer(tenant, amountToReturn);

        emit GuaranteeReturned(tenant, amountToReturn);
    }

    // Función para obtener el estado del contrato
    function getContractStatus() external view returns (
        uint256 guarantee,
        bool deposited,
        uint256 relativeYear,
        uint256 currentMonth,
        Date memory endTime,
        uint256 currentMonthPaidAmount
    ) {
        (relativeYear, currentMonth) = currentMonthAndYear();
        uint256 monthIndex = relativeYear * 12 + (currentMonth - startMonth + 1 + (currentMonth < startMonth ? 12 : 0));
        return (
            guaranteeBalance,
            guaranteeDeposited,
            relativeYear,
            currentMonth,
            getContractEndTime(),
            monthPaidAmount[monthIndex]
        );
    }

    // Función para recuperar fondos atrapados
    function recoverTokens(uint256 amount) external onlyLandlord {
        (uint256 year, uint256 month) = currentMonthAndYear();
        uint256 relativeYear = year; // Almacenar el año retornado
        uint256 monthIndex = relativeYear * 12 + (month - startMonth + 1 + (month < startMonth ? 12 : 0));
        require(amount <= usdtToken.balanceOf(address(this)) - guaranteeBalance - monthPaidAmount[monthIndex], "No se puede retirar la garantia o pagos pendientes");
        usdtToken.transfer(landlord, amount);
    }
}
