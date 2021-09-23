CREATE TABLE IF NOT EXISTS `bossmenu_accounts` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `account` text NOT NULL,
    `money` text NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('police', '1000000');
INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('ambulance', '0');
INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('realestate', '0');
INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('taxi', '0');
INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('cardealer', '0');
INSERT INTO `bossmenu_accounts`(`account`, `money`) VALUES('mechanic', '0');