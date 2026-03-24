-- =============================================================
-- SCHMEA in ORACLE: CREATE ALL TABLES (Help Desk)
-- =============================================================

-- 1. Companies
CREATE TABLE companies (
    company_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name  VARCHAR2(100) NOT NULL,
    industry      VARCHAR2(50),
    tier          VARCHAR2(20) DEFAULT 'standard' CHECK (tier IN ('standard', 'premium', 'enterprise')),
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT uq_company_name UNIQUE (company_name)
);

-- 2. Users
CREATE TABLE users (
    user_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id    NUMBER NOT NULL,
    full_name     VARCHAR2(100) NOT NULL,
    email         VARCHAR2(150) NOT NULL,
    role          VARCHAR2(20) NOT NULL CHECK (role IN ('customer', 'technician', 'admin')),
    department    VARCHAR2(50),
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT fk_user_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);

-- 3. Tickets
CREATE TABLE tickets (
    ticket_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id    NUMBER NOT NULL,
    submitted_by  NUMBER NOT NULL,
    assigned_to   NUMBER,
    subject       VARCHAR2(200) NOT NULL,
    description   CLOB,
    priority      VARCHAR2(10) DEFAULT 'medium' NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status        VARCHAR2(20) DEFAULT 'open' NOT NULL CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'reopened')),
    category      VARCHAR2(50),
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    resolved_at   TIMESTAMP,
    CONSTRAINT fk_ticket_company   FOREIGN KEY (company_id)   REFERENCES companies(company_id),
    CONSTRAINT fk_ticket_submitted FOREIGN KEY (submitted_by) REFERENCES users(user_id),
    CONSTRAINT fk_ticket_assigned  FOREIGN KEY (assigned_to)  REFERENCES users(user_id)
);

-- 4. Ticket Status History
CREATE TABLE ticket_status_history (
    history_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER NOT NULL,
    changed_by    NUMBER NOT NULL,
    old_status    VARCHAR2(20),
    new_status    VARCHAR2(20) NOT NULL,
    notes         VARCHAR2(500),
    changed_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tsh_ticket FOREIGN KEY (ticket_id)   REFERENCES tickets(ticket_id),
    CONSTRAINT fk_tsh_user   FOREIGN KEY (changed_by)  REFERENCES users(user_id)
);

-- 5. Knowledge Base Articles
CREATE TABLE kb_articles (
    article_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id     NUMBER NOT NULL,
    title         VARCHAR2(200) NOT NULL,
    content       CLOB,
    category      VARCHAR2(50),
    view_count    NUMBER DEFAULT 0,
    is_published  NUMBER(1) DEFAULT 1 CHECK (is_published IN (0, 1)),
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    updated_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_kb_author FOREIGN KEY (author_id) REFERENCES users(user_id)
);

-- DS-1: User Events
CREATE TABLE user_events (
    event_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       NUMBER NOT NULL,
    ticket_id     NUMBER,
    event_type    VARCHAR2(50) NOT NULL,
    session_id    VARCHAR2(64),
    ip_address    VARCHAR2(45),
    user_agent    VARCHAR2(300),
    event_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_ue_user   FOREIGN KEY (user_id)   REFERENCES users(user_id),
    CONSTRAINT fk_ue_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- DS-2: Ticket Daily Snapshots
CREATE TABLE ticket_daily_snapshot (
    snapshot_date DATE NOT NULL,
    company_id    NUMBER REFERENCES companies(company_id),
    open_tickets  NUMBER DEFAULT 0,
    solved_today  NUMBER DEFAULT 0,
    avg_handle_time_hrs NUMBER,
    PRIMARY KEY (snapshot_date, company_id)
);

-- DS-3: CSAT Scores
CREATE TABLE csat_scores (
    csat_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER NOT NULL,
    rated_by      NUMBER NOT NULL,
    score         NUMBER(2) NOT NULL CHECK (score BETWEEN 1 AND 5),
    comments      VARCHAR2(1000),
    rated_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_csat_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    CONSTRAINT fk_csat_user   FOREIGN KEY (rated_by)  REFERENCES users(user_id),
    CONSTRAINT uq_csat_ticket UNIQUE (ticket_id)
);

-- DS-4: Ticket-to-KB Article Links
CREATE TABLE ticket_kb_references (
    ref_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id      NUMBER NOT NULL,
    article_id     NUMBER NOT NULL,
    linked_by      NUMBER NOT NULL,
    linked_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tkr_ticket  FOREIGN KEY (ticket_id)  REFERENCES tickets(ticket_id),
    CONSTRAINT fk_tkr_article FOREIGN KEY (article_id) REFERENCES kb_articles(article_id),
    CONSTRAINT fk_tkr_user    FOREIGN KEY (linked_by)  REFERENCES users(user_id),
    CONSTRAINT uq_ticket_article UNIQUE (ticket_id, article_id)
);

-- DS-5: Engineered Features for ML
CREATE TABLE ticket_features (
    feature_id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id              NUMBER NOT NULL,
    subject_word_count     NUMBER,
    desc_word_count        NUMBER,
    hour_of_day            NUMBER,
    day_of_week            NUMBER,
    is_weekend             NUMBER(1),
    reopen_count           NUMBER DEFAULT 0,
    time_to_first_resp_hrs NUMBER(10,2),
    time_to_resolve_hrs    NUMBER(10,2),
    priority_encoded       NUMBER,
    computed_at            TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tf_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    CONSTRAINT uq_tf_ticket UNIQUE (ticket_id)
);

-- DS-6: Weekly Company Stats
CREATE TABLE company_weekly_stats (
    stat_id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id          NUMBER NOT NULL,
    week_start          DATE NOT NULL,
    total_tickets       NUMBER DEFAULT 0,
    open_tickets        NUMBER DEFAULT 0,
    resolved_tickets    NUMBER DEFAULT 0,
    avg_resolution_hrs  NUMBER(10,2),
    critical_count      NUMBER DEFAULT 0,
    high_count          NUMBER DEFAULT 0,
    avg_csat            NUMBER(4,2),
    CONSTRAINT fk_cws_company FOREIGN KEY (company_id) REFERENCES companies(company_id),
    CONSTRAINT uq_cws UNIQUE (company_id, week_start)
);

-- DS-7: Ticket Assignment Log
CREATE TABLE ticket_assignments (
    assignment_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id       NUMBER NOT NULL,
    assigned_from   NUMBER,
    assigned_to     NUMBER NOT NULL,
    assigned_by     NUMBER NOT NULL,
    assigned_at     TIMESTAMP DEFAULT SYSTIMESTAMP,
    reason          VARCHAR2(200),
    CONSTRAINT fk_ta_ticket FOREIGN KEY (ticket_id)     REFERENCES tickets(ticket_id),
    CONSTRAINT fk_ta_from   FOREIGN KEY (assigned_from) REFERENCES users(user_id),
    CONSTRAINT fk_ta_to     FOREIGN KEY (assigned_to)   REFERENCES users(user_id),
    CONSTRAINT fk_ta_by     FOREIGN KEY (assigned_by)   REFERENCES users(user_id)
);

-- DS-8: Ticket Comments
CREATE TABLE ticket_comments (
    comment_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER NOT NULL,
    author_id     NUMBER NOT NULL,
    body          CLOB NOT NULL,
    is_internal   NUMBER(1) DEFAULT 0 CHECK (is_internal IN (0, 1)),
    created_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_tc_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    CONSTRAINT fk_tc_author FOREIGN KEY (author_id) REFERENCES users(user_id)
);

-- DS-9: SLA Policies
CREATE TABLE sla_policies (
    sla_id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id          NUMBER NOT NULL,
    priority            VARCHAR2(10) NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    first_response_hrs  NUMBER(5,1) NOT NULL,
    resolution_hrs      NUMBER(5,1) NOT NULL,
    CONSTRAINT fk_sla_company FOREIGN KEY (company_id) REFERENCES companies(company_id),
    CONSTRAINT uq_sla UNIQUE (company_id, priority)
);

-- DS-10: SLA Breach Records
CREATE TABLE sla_breaches (
    breach_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id       NUMBER NOT NULL,
    sla_id          NUMBER NOT NULL,
    breach_type     VARCHAR2(20) NOT NULL CHECK (breach_type IN ('response', 'resolution')),
    target_hrs      NUMBER(5,1),
    actual_hrs      NUMBER(10,2),
    breach_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_sb_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    CONSTRAINT fk_sb_sla    FOREIGN KEY (sla_id)    REFERENCES sla_policies(sla_id),
    CONSTRAINT uq_sb UNIQUE (ticket_id, breach_type)
);

-- DS-11: Tags System
CREATE TABLE tags (
    tag_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tag_name  VARCHAR2(50) NOT NULL,
    CONSTRAINT uq_tag_name UNIQUE (tag_name)
);

CREATE TABLE ticket_tags (
    ticket_id NUMBER NOT NULL,
    tag_id    NUMBER NOT NULL,
    CONSTRAINT pk_ticket_tags PRIMARY KEY (ticket_id, tag_id),
    CONSTRAINT fk_tt_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
    CONSTRAINT fk_tt_tag    FOREIGN KEY (tag_id)    REFERENCES tags(tag_id)
);

-- DS-12: Model Predictions
CREATE TABLE model_predictions (
    pred_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id       NUMBER NOT NULL,
    model_name      VARCHAR2(100) NOT NULL,
    model_version   VARCHAR2(20),
    predicted_label VARCHAR2(50),
    confidence      NUMBER(5,4),
    predicted_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_mp_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);
