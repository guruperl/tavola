CREATE TABLE `poll_choice` (
  `choice_id` int(11) NOT NULL AUTO_INCREMENT,
  `poll_id` int(11) NOT NULL,
  `choice` varchar(255) NOT NULL,
  `votes` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`choice_id`),
  KEY `poll_id` (`poll_id`),
  CONSTRAINT `poll_choice_ibfk_1` FOREIGN KEY (`poll_id`) REFERENCES `poll_question` (`poll_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1
