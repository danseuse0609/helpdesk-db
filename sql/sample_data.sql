-- =============================================================
-- Help Desk Ticket System - sample_data.sql
-- CS-630 Final Project
-- =============================================================
-- Run AFTER schema.sql
-- Inserts representative data for all core and DS tables
-- =============================================================

-- ---------------------------------------------------------------
-- Companies
-- ---------------------------------------------------------------
INSERT INTO companies (company_name, industry, tier) VALUES ('Acme Corp',         'Manufacturing',  'enterprise');
INSERT INTO companies (company_name, industry, tier) VALUES ('Bright Solutions',  'Technology',     'premium');
INSERT INTO companies (company_name, industry, tier) VALUES ('Cedar Finance',     'Finance',        'enterprise');
INSERT INTO companies (company_name, industry, tier) VALUES ('Delta Retail',      'Retail',         'standard');
INSERT INTO companies (company_name, industry, tier) VALUES ('Echo Logistics',    'Logistics',      'standard');

-- ---------------------------------------------------------------
-- Users  (company_id 1-5 map to companies above)
-- ---------------------------------------------------------------
-- Technicians (company 1 = internal IT/helpdesk team)
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (1, 'Alice Ng',      'alice@acme.com',       'technician', 'IT Support');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (1, 'Bob Patel',     'bob@acme.com',         'technician', 'IT Support');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (1, 'Carol Kim',     'carol@acme.com',       'technician', 'Network');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (1, 'Dan Reyes',     'dan@acme.com',         'admin',      'IT Support');

-- Customers from various companies
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (2, 'Eva Chen',      'eva@bright.com',       'customer',   'Engineering');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (2, 'Frank Wu',      'frank@bright.com',     'customer',   'Engineering');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (3, 'Grace Obi',     'grace@cedar.com',      'customer',   'Finance');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (3, 'Hank Lee',      'hank@cedar.com',       'customer',   'IT');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (4, 'Iris Smith',    'iris@delta.com',       'customer',   'Operations');
INSERT INTO users (company_id, full_name, email, role, department)
  VALUES (5, 'Jake Torres',   'jake@echo.com',        'customer',   'Logistics');

-- ---------------------------------------------------------------
-- Tickets
-- ---------------------------------------------------------------
-- Ticket 1: resolved
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category, resolved_at)
  VALUES (2, 5, 1, 'VPN not connecting after update',
          'After the latest Windows update, VPN client fails to authenticate.',
          'high', 'resolved', 'Network',
          SYSTIMESTAMP - INTERVAL '2' DAY);

-- Ticket 2: in progress
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category)
  VALUES (2, 6, 2, 'Email client crashes on startup',
          'Outlook crashes immediately after opening. Error code 0x80070005.',
          'medium', 'in_progress', 'Email');

-- Ticket 3: open / unassigned
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category)
  VALUES (3, 7, NULL, 'Cannot access financial reporting dashboard',
          'Receiving 403 Forbidden when opening the BI dashboard.',
          'critical', 'open', 'Access');

-- Ticket 4: resolved
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category, resolved_at)
  VALUES (3, 8, 3, 'Slow WiFi in conference rooms',
          'Bandwidth drops to under 1 Mbps in rooms B201-B205.',
          'low', 'resolved', 'Network',
          SYSTIMESTAMP - INTERVAL '5' DAY);

-- Ticket 5: closed
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category, resolved_at)
  VALUES (4, 9, 1, 'Printer offline on Floor 3',
          'HP LaserJet Pro shows offline in print queue despite being powered on.',
          'medium', 'closed', 'Hardware',
          SYSTIMESTAMP - INTERVAL '10' DAY);

-- Ticket 6: open
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category)
  VALUES (5, 10, 2, 'ERP login loop after password reset',
          'User stuck in infinite login redirect after password change.',
          'high', 'open', 'Authentication');

-- Ticket 7: resolved (reopened then resolved)
INSERT INTO tickets (company_id, submitted_by, assigned_to, subject, description, priority, status, category, resolved_at)
  VALUES (2, 5, 1, 'Shared drive permissions issue',
          'Cannot write to /shared/projects even though user is in the correct AD group.',
          'medium', 'resolved', 'Access',
          SYSTIMESTAMP - INTERVAL '1' DAY);

-- ---------------------------------------------------------------
-- Ticket Status History
-- ---------------------------------------------------------------
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (1, 5, NULL,        'open',        'Ticket created');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (1, 1, 'open',      'in_progress', 'Assigned and investigating');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (1, 1, 'in_progress','resolved',   'KB article #2 applied; VPN client reinstalled');

INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (2, 6, NULL,        'open',        'Ticket created');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (2, 2, 'open',      'in_progress', 'Reproducing issue in test env');

INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (7, 5, NULL,        'open',        'Ticket created');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (7, 1, 'open',      'resolved',    'Permissions updated');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (7, 5, 'resolved',  'reopened',    'Issue came back after patch Tuesday');
INSERT INTO ticket_status_history (ticket_id, changed_by, old_status, new_status, notes)
  VALUES (7, 1, 'reopened',  'resolved',    'Root cause fixed in AD group policy');

-- ---------------------------------------------------------------
-- Knowledge Base Articles
-- ---------------------------------------------------------------
INSERT INTO kb_articles (author_id, title, category, content, view_count)
  VALUES (1, 'How to Reinstall the VPN Client', 'Network',
          'Step 1: Uninstall current client. Step 2: Download latest from IT portal. Step 3: Run installer as admin.',
          45);
INSERT INTO kb_articles (author_id, title, category, content, view_count)
  VALUES (3, 'Troubleshooting WiFi in Conference Rooms', 'Network',
          'Check AP association, verify DHCP lease, reset network adapter if needed.',
          22);
INSERT INTO kb_articles (author_id, title, category, content, view_count)
  VALUES (2, 'Resetting Outlook to Default Profile', 'Email',
          'Navigate to Control Panel > Mail > Show Profiles. Remove and recreate profile.',
          67);
INSERT INTO kb_articles (author_id, title, category, content, view_count)
  VALUES (1, 'Fixing Printer Offline Status', 'Hardware',
          'Right-click printer > See what''s printing > Printer menu > Uncheck Use Printer Offline.',
          33);

-- ---------------------------------------------------------------
-- Ticket KB References
-- ---------------------------------------------------------------
INSERT INTO ticket_kb_references (ticket_id, article_id, linked_by) VALUES (1, 1, 1);
INSERT INTO ticket_kb_references (ticket_id, article_id, linked_by) VALUES (4, 2, 3);
INSERT INTO ticket_kb_references (ticket_id, article_id, linked_by) VALUES (5, 4, 1);

-- ---------------------------------------------------------------
-- Ticket Comments
-- ---------------------------------------------------------------
INSERT INTO ticket_comments (ticket_id, author_id, body, is_internal)
  VALUES (1, 1, 'I can reproduce this. Looks like the VPN DNS suffix changed in the update.', 1);
INSERT INTO ticket_comments (ticket_id, author_id, body, is_internal)
  VALUES (1, 5, 'Thank you! The reinstall fixed it.', 0);
INSERT INTO ticket_comments (ticket_id, author_id, body, is_internal)
  VALUES (2, 2, 'Tried safe mode — same crash. Escalating to Bob for deeper look.', 1);
INSERT INTO ticket_comments (ticket_id, author_id, body, is_internal)
  VALUES (3, 7, 'This is blocking end-of-month reporting. Please prioritize.', 0);

-- ---------------------------------------------------------------
-- Ticket Assignments
-- ---------------------------------------------------------------
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (1, NULL, 1, 4, 'First assignment');
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (2, NULL, 2, 4, 'First assignment');
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (4, NULL, 3, 4, 'Network team handles WiFi tickets');
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (5, NULL, 1, 4, 'First assignment');
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (6, NULL, 2, 4, 'First assignment');
INSERT INTO ticket_assignments (ticket_id, assigned_from, assigned_to, assigned_by, reason)
  VALUES (7, NULL, 1, 4, 'First assignment');

-- ---------------------------------------------------------------
-- CSAT Scores (for resolved/closed tickets)
-- ---------------------------------------------------------------
INSERT INTO csat_scores (ticket_id, rated_by, score, comments)
  VALUES (1, 5, 5, 'Super fast resolution, great communication!');
INSERT INTO csat_scores (ticket_id, rated_by, score, comments)
  VALUES (4, 8, 4, 'Fixed but took a bit longer than expected.');
INSERT INTO csat_scores (ticket_id, rated_by, score, comments)
  VALUES (5, 9, 3, 'Resolved, but I had to follow up twice.');
INSERT INTO csat_scores (ticket_id, rated_by, score, comments)
  VALUES (7, 5, 4, 'Had to reopen once but final fix was solid.');

-- ---------------------------------------------------------------
-- SLA Policies
-- ---------------------------------------------------------------
-- Enterprise tier: tight SLAs
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (2, 'critical', 1,   4);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (2, 'high',     2,  24);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (2, 'medium',   4,  72);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (2, 'low',      8, 168);

INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (3, 'critical', 1,   4);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (3, 'high',     2,  24);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (3, 'medium',   8,  72);
INSERT INTO sla_policies (company_id, priority, first_response_hrs, resolution_hrs)
  VALUES (3, 'low',     24, 240);

-- ---------------------------------------------------------------
-- Tags
-- ---------------------------------------------------------------
INSERT INTO tags (tag_name) VALUES ('vpn');
INSERT INTO tags (tag_name) VALUES ('email');
INSERT INTO tags (tag_name) VALUES ('network');
INSERT INTO tags (tag_name) VALUES ('access');
INSERT INTO tags (tag_name) VALUES ('hardware');
INSERT INTO tags (tag_name) VALUES ('authentication');
INSERT INTO tags (tag_name) VALUES ('urgent');

-- ---------------------------------------------------------------
-- Ticket Tags
-- ---------------------------------------------------------------
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (1, 1);  -- vpn
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (1, 3);  -- network
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (2, 2);  -- email
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (3, 4);  -- access
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (3, 7);  -- urgent
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (4, 3);  -- network
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (5, 5);  -- hardware
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (6, 6);  -- authentication
INSERT INTO ticket_tags (ticket_id, tag_id) VALUES (7, 4);  -- access

-- ---------------------------------------------------------------
-- Technician Daily Snapshot (sample for Alice on recent days)
-- ---------------------------------------------------------------
INSERT INTO technician_daily_snapshot (user_id, snapshot_date, tickets_assigned, tickets_resolved, avg_resolution_hrs, csat_avg, reopened_count)
  VALUES (1, TRUNC(SYSDATE) - 7, 3, 2, 18.5, 4.5, 0);
INSERT INTO technician_daily_snapshot (user_id, snapshot_date, tickets_assigned, tickets_resolved, avg_resolution_hrs, csat_avg, reopened_count)
  VALUES (1, TRUNC(SYSDATE) - 6, 2, 2, 12.0, 5.0, 1);
INSERT INTO technician_daily_snapshot (user_id, snapshot_date, tickets_assigned, tickets_resolved, avg_resolution_hrs, csat_avg, reopened_count)
  VALUES (2, TRUNC(SYSDATE) - 7, 4, 3, 22.1, 3.7, 0);

-- ---------------------------------------------------------------
-- Ticket Features (engineered for ML)
-- ---------------------------------------------------------------
INSERT INTO ticket_features
  (ticket_id, subject_word_count, desc_word_count, hour_of_day, day_of_week,
   is_weekend, reopen_count, time_to_first_resp_hrs, time_to_resolve_hrs, priority_encoded)
  VALUES (1, 7, 12, 9, 2, 0, 0, 1.2, 36.5, 3);
INSERT INTO ticket_features
  (ticket_id, subject_word_count, desc_word_count, hour_of_day, day_of_week,
   is_weekend, reopen_count, time_to_first_resp_hrs, time_to_resolve_hrs, priority_encoded)
  VALUES (5, 5, 15, 14, 4, 0, 0, 0.5, 240.0, 2);

-- ---------------------------------------------------------------
-- User Events (sample activity log)
-- ---------------------------------------------------------------
INSERT INTO user_events (user_id, ticket_id, event_type, session_id)
  VALUES (5, NULL, 'login', 'sess_abc123');
INSERT INTO user_events (user_id, ticket_id, event_type, session_id)
  VALUES (5, 1, 'submit_ticket', 'sess_abc123');
INSERT INTO user_events (user_id, ticket_id, event_type, session_id)
  VALUES (1, 1, 'view_ticket', 'sess_def456');
INSERT INTO user_events (user_id, ticket_id, event_type, session_id)
  VALUES (7, 3, 'submit_ticket', 'sess_ghi789');

COMMIT;
