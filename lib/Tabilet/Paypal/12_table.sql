INSERT INTO def_type (typeid,name,total_role) VALUES (4,"Personal",3);
INSERT INTO def_type (typeid,name,is_vue,is_graph,lang,total_account) VALUES (5,"Team",'Yes','No','PHP',3);
INSERT INTO def_type (typeid,name,is_vue,is_graph,lang,total_account) VALUES (6,"Enterprise",'Yes','Yes','PHP,GO,Java,Perl',10);
-- is_default means: among all plans with the same typeid, only one has is_default=Yes which is the default planid
INSERT INTO def_plan (typeid,name,biller,biller_id,is_default,price,recurring,trial) VALUES (4,"Personal Plan",'PAYPAL',COALESCE(@TABILET_PAYPAL_PLAN_ID_PERSONAL, ''),'Yes',50,'Monthly',0);
INSERT INTO def_plan (typeid,name,biller,biller_id,is_default,price,recurring,trial) VALUES (5,"Team Plan",'PAYPAL',COALESCE(@TABILET_PAYPAL_PLAN_ID_TEAM, ''),'Yes',1000,'Yearly',0);
INSERT INTO def_plan (typeid,name,biller,biller_id,is_default,price,recurring,trial) VALUES (6,"Enterprise Plan",'PAYPAL',COALESCE(@TABILET_PAYPAL_PLAN_ID_ENTERPRISE, ''),'Yes',9000,'Yearly',0);
