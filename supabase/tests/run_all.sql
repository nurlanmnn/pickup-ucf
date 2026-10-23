\set ON_ERROR_STOP on
BEGIN;
\ir helpers.sql
\ir phase_a_notifications.sql
\ir phase_b_sports.sql
\ir phase_b_onboarding.sql
\ir phase_c_recurrence.sql
\ir phase_c_blocks.sql
\ir phase_c_reports.sql
\ir phase_d_tier1.sql
\ir phase_d_tier2.sql
\ir phase_e_live_activities.sql
\ir phase_f_device_token_ownership.sql
\ir phase_g_moderation.sql
\ir phase_h_atomic_creation.sql
\ir phase_i_input_boundaries.sql
\ir phase_j_rpc_grants.sql
\ir phase_k_join_leave.sql
\ir phase_l_account_deletion.sql
\ir phase_m_roster_access.sql
\ir phase_n_session_status.sql
\ir phase_o_host_edit_boundaries.sql
\ir phase_p_waitlist_retry.sql
\ir phase_q_participant_reads.sql
ROLLBACK;
