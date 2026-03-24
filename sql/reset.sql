-- =============================================================
-- Help Desk Ticket System - reset.sql
-- CS-630 Final Project
-- =============================================================
-- WARNING: This permanently drops all project tables.
-- Run this to start fresh, then re-run schema.sql + sample_data.sql
-- Drop order respects FK constraints (children first, parents last)
-- =============================================================

-- DS tables first (depend on core tables)
DROP TABLE model_predictions       CASCADE CONSTRAINTS PURGE;
DROP TABLE ticket_tags             CASCADE CONSTRAINTS PURGE;
DROP TABLE tags                    CASCADE CONSTRAINTS PURGE;
DROP TABLE sla_breaches            CASCADE CONSTRAINTS PURGE;
DROP TABLE sla_policies            CASCADE CONSTRAINTS PURGE;
DROP TABLE ticket_features         CASCADE CONSTRAINTS PURGE;
DROP TABLE company_weekly_stats    CASCADE CONSTRAINTS PURGE;
DROP TABLE csat_scores             CASCADE CONSTRAINTS PURGE;
DROP TABLE ticket_kb_references    CASCADE CONSTRAINTS PURGE;
DROP TABLE technician_daily_snapshot CASCADE CONSTRAINTS PURGE;
DROP TABLE user_events             CASCADE CONSTRAINTS PURGE;

-- Core tables
DROP TABLE ticket_assignments      CASCADE CONSTRAINTS PURGE;
DROP TABLE ticket_comments         CASCADE CONSTRAINTS PURGE;
DROP TABLE ticket_status_history   CASCADE CONSTRAINTS PURGE;
DROP TABLE kb_articles             CASCADE CONSTRAINTS PURGE;
DROP TABLE tickets                 CASCADE CONSTRAINTS PURGE;
DROP TABLE users                   CASCADE CONSTRAINTS PURGE;
DROP TABLE companies               CASCADE CONSTRAINTS PURGE;
