INSERT INTO project VALUES (1,'Smart Healthcare Project Management System','Deliver a secure, integrated system for appointments, lab reports, doctor schedules, online consultations and billing across five hospitals.','2026-08-03','2026-11-23',5000000,'At risk','Appointments; patient records; laboratory reports; doctor schedules; online consultations; billing.','Hospital management; patients; doctors; lab staff; finance teams; project team');
INSERT INTO requirements(title,description,priority,status,source) VALUES
('Patient appointment scheduling','Book, reschedule and cancel appointments across five hospitals.','Must have','Approved','Baseline'),
('Patient record management','Maintain authorized patient demographics and visit records.','Must have','Approved','Baseline'),
('Laboratory reports','Publish and view verified lab results.','Must have','Approved','Baseline'),
('Doctor schedules','Manage availability and prevent double booking.','Must have','Approved','Baseline'),
('Online consultations','Support secure remote consultations.','Should have','Approved','Baseline'),
('Hospital billing','Track charges, invoices and payment status.','Must have','Approved','Baseline'),
('AI preliminary diagnosis','Clinician-reviewed decision support; never replace medical judgement.','Could have','Pending','Change request CR-001'),
('Mobile application','Provide patient and clinician workflows on mobile devices.','Should have','Pending','Change request CR-001');
INSERT INTO changes(title,justification,cost_impact,days_impact,status) VALUES ('CR-001 · AI diagnosis + mobile app','Hospital management requested diagnosis support and mobile access after baseline approval.',800000,21,'Pending');
INSERT INTO activities(code,name,owner,start_date,duration,cost,actual_cost,progress,dependency,milestone) VALUES
('1.1','Requirements & charter','Project manager','2026-08-03',10,450000,420000,1.0,'',1),
('1.2','Architecture & database design','Database developer','2026-08-13',12,520000,540000,1.0,'1.1',0),
('2.1','Appointment scheduling module','Backend developer 1','2026-08-25',24,850000,920000,0.78,'1.2',0),
('2.2','Patient records & laboratory reports','Backend developer 2','2026-09-18',25,950000,890000,0.68,'1.2',0),
('2.3','Doctor schedules & consultations','Frontend developer 1','2026-09-18',24,740000,570000,0.70,'1.2',0),
('2.4','Billing & finance module','Frontend developer 2','2026-10-12',18,600000,260000,0.34,'2.2',0),
('3.1','Integration & system testing','Quality assurance engineer','2026-10-20',19,520000,0,0.12,'2.1,2.2,2.3,2.4',0),
('3.2','Hospital pilot & handover','Project manager','2026-11-08',15,370000,0,0,'3.1',1);
INSERT INTO defects(title,severity,assignee,status,reported) VALUES
('Appointment double-booking under concurrent requests','Critical','Backend developer 1','Open','2026-10-18'),
('Patient record mismatch after update','Critical','Database developer','In progress','2026-10-19'),
('Lab report export formatting','Medium','Frontend developer 2','Open','2026-10-21');
INSERT INTO risks(title,likelihood,impact,response,owner,status) VALUES
('Critical defects delay system test',4,5,'Daily triage; block release until both critical defects pass regression.','QA engineer','Open'),
('Late change request exceeds baseline',4,4,'Submit impact review; use contingency only after sponsor approval.','Project manager','Open'),
('Patient data exposure',2,5,'Least privilege, encryption, audit trail and security review before pilot.','Database developer','Open');
INSERT INTO checklist(item,deliverable,result,inspector) VALUES
('Role-based access and audit logs','Security design','Pass','QA engineer'),
('Appointment conflict and concurrency tests','Scheduling module','Fail','QA engineer'),
('Patient record integrity and recovery','Patient records','In progress','Database developer'),
('Five-hospital billing reconciliation','Billing module','Not tested','QA engineer'),
('Pilot sign-off from hospital stakeholders','Release readiness','Pending','Project manager');
