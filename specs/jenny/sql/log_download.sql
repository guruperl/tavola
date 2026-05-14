CREATE TABLE `log_download` (
  `log_id` int(11) NOT NULL AUTO_INCREMENT,
  `theday` date DEFAULT NULL,
  `num` int(11) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
