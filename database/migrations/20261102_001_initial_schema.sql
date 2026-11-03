-- SiDonor initial Supabase schema
-- Region: Southeast Asia (Singapore), confirmed from the project dashboard.
-- Safe to re-run: tables/indexes/policies/functions are idempotent where practical.
-- Medical criteria and ABO/Rh compatibility remain provisional and must be confirmed by UDD PMI.

begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null default '',
    nim text unique,
    role text not null default 'student' check (role in ('student', 'organizer', 'admin')),
    account_status text not null default 'pending' check (account_status in ('pending', 'active', 'rejected', 'suspended')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.donor_profiles (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    blood_group text check (blood_group in ('A', 'B', 'AB', 'O')),
    rhesus text check (rhesus in ('+', '-')),
    blood_group_verified boolean not null default false,
    willing_to_donate boolean not null default false,
    screening_state text not null default 'not_completed' check (screening_state in ('not_completed', 'needs_review', 'initial_indication')),
    last_screening_at timestamptz,
    next_eligible_at date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Contact data is isolated from donor-search fields. Admin access is only through the
-- per-response function below after the donor has accepted that specific request.
create table if not exists public.private_contacts (
    user_id uuid primary key references public.profiles(id) on delete cascade,
    whatsapp_number text not null,
    updated_at timestamptz not null default now()
);

create table if not exists public.consents (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    consent_version text not null,
    purpose text not null,
    granted_at timestamptz not null default now(),
    withdrawn_at timestamptz,
    created_at timestamptz not null default now()
);

-- Store only minimal screening fields; no blood pressure, hemoglobin, or detailed diagnosis.
create table if not exists public.screening_records (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    age_years smallint not null check (age_years between 1 and 120),
    weight_kg numeric(5,2) not null check (weight_kg > 0 and weight_kg < 400),
    needs_staff_review boolean not null default false,
    initial_result text not null check (initial_result in ('initial_indication', 'needs_review', 'outside_initial_reference')),
    assessed_at timestamptz not null default now()
);

create table if not exists public.blood_requests (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references public.profiles(id),
    requester_name text not null,
    requester_phone text not null,
    requester_verified_at timestamptz,
    blood_group text not null check (blood_group in ('A', 'B', 'AB', 'O')),
    rhesus text not null check (rhesus in ('+', '-')),
    units_required smallint not null check (units_required > 0),
    location text not null,
    urgency text not null default 'planned' check (urgency in ('emergency', 'planned')),
    status text not null default 'pending_verification' check (status in ('pending_verification', 'open', 'fulfilled', 'closed', 'expired')),
    expires_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    closed_at timestamptz
);

create table if not exists public.request_candidates (
    id uuid primary key default gen_random_uuid(),
    request_id uuid not null references public.blood_requests(id) on delete cascade,
    donor_id uuid not null references public.donor_profiles(user_id) on delete cascade,
    notification_channel text not null default 'in_app' check (notification_channel in ('whatsapp', 'in_app')),
    delivery_state text not null default 'queued' check (delivery_state in ('queued', 'sent', 'failed')),
    response_status text not null default 'pending' check (response_status in ('pending', 'accepted', 'declined', 'expired')),
    notified_at timestamptz,
    responded_at timestamptz,
    created_at timestamptz not null default now(),
    unique (request_id, donor_id)
);

create table if not exists public.donor_history (
    id uuid primary key default gen_random_uuid(),
    donor_id uuid not null references public.donor_profiles(user_id) on delete cascade,
    recorded_by uuid not null references public.profiles(id),
    request_id uuid references public.blood_requests(id) on delete set null,
    donation_date date not null,
    outcome text not null check (outcome in ('successful', 'did_not_donate', 'did_not_pass_official_screening')),
    reason_note text,
    next_eligible_at date,
    created_at timestamptz not null default now()
);

create table if not exists public.donor_activities (
    id uuid primary key default gen_random_uuid(),
    organizer_id uuid not null references public.profiles(id),
    title text not null,
    starts_at timestamptz not null,
    location text not null,
    quota integer not null check (quota > 0),
    partner_name text,
    status text not null default 'pending_review' check (status in ('pending_review', 'approved', 'rejected', 'completed', 'cancelled')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.activity_registrations (
    id uuid primary key default gen_random_uuid(),
    activity_id uuid not null references public.donor_activities(id) on delete cascade,
    student_id uuid not null references public.profiles(id) on delete cascade,
    status text not null default 'registered' check (status in ('registered', 'cancelled', 'attended', 'absent')),
    registered_at timestamptz not null default now(),
    unique (activity_id, student_id)
);

create table if not exists public.app_settings (
    setting_key text primary key,
    setting_value jsonb not null,
    updated_by uuid references public.profiles(id),
    updated_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
    id bigint generated always as identity primary key,
    actor_id uuid not null references public.profiles(id),
    action text not null,
    entity_name text not null,
    entity_id text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_profiles_status_role on public.profiles (account_status, role);
create index if not exists idx_donor_match on public.donor_profiles (blood_group, rhesus, screening_state, next_eligible_at) where willing_to_donate = true;
create index if not exists idx_consents_user_active on public.consents (user_id, granted_at desc) where withdrawn_at is null;
create index if not exists idx_screenings_user_time on public.screening_records (user_id, assessed_at desc);
create index if not exists idx_requests_status_created on public.blood_requests (status, created_at desc);
create index if not exists idx_candidates_request_status on public.request_candidates (request_id, response_status);
create index if not exists idx_candidates_donor_status on public.request_candidates (donor_id, response_status);
create index if not exists idx_history_donor_date on public.donor_history (donor_id, donation_date desc);
create index if not exists idx_activities_status_start on public.donor_activities (status, starts_at);
create index if not exists idx_registrations_activity on public.activity_registrations (activity_id, status);
create index if not exists idx_audit_created on public.admin_audit_log (created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce((select p.role from public.profiles p where p.id = auth.uid() and p.account_status = 'active'), 'student');
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select public.current_app_role() = 'admin';
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, full_name, nim)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', ''),
        nullif(new.raw_user_meta_data ->> 'nim', '')
    )
    on conflict (id) do nothing;

    insert into public.donor_profiles (user_id)
    values (new.id)
    on conflict (user_id) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.set_donor_verification(p_user_id uuid, p_verified boolean, p_account_status text default 'active')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not public.is_admin() then
        raise exception 'Admin role required';
    end if;
    if p_account_status not in ('active', 'rejected', 'pending', 'suspended') then
        raise exception 'Invalid account status';
    end if;
    update public.profiles set account_status = p_account_status where id = p_user_id;
    update public.donor_profiles set blood_group_verified = p_verified, updated_at = now() where user_id = p_user_id;
end;
$$;

create or replace function public.respond_to_candidate(p_candidate_id uuid, p_response text)
returns public.request_candidates
language plpgsql
security definer
set search_path = ''
as $$
declare
    changed public.request_candidates;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;
    if p_response not in ('accepted', 'declined') then
        raise exception 'Response must be accepted or declined';
    end if;
    update public.request_candidates
       set response_status = p_response, responded_at = now()
     where id = p_candidate_id
       and donor_id = auth.uid()
       and response_status = 'pending'
       and exists (select 1 from public.donor_profiles dp where dp.user_id = auth.uid() and dp.willing_to_donate)
       and exists (select 1 from public.consents c where c.user_id = auth.uid() and c.withdrawn_at is null)
       and exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_status = 'active')
     returning * into changed;
    if changed.id is null then
        raise exception 'Candidate response not found, already answered, or not owned by user';
    end if;
    return changed;
end;
$$;

create or replace function public.get_accepted_donor_contact(p_candidate_id uuid)
returns table (whatsapp_number text, donor_email text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if not public.is_admin() then
        raise exception 'Admin role required';
    end if;
    return query
    select pc.whatsapp_number, au.email::text
      from public.request_candidates rc
      join public.private_contacts pc on pc.user_id = rc.donor_id
      join auth.users au on au.id = rc.donor_id
     where rc.id = p_candidate_id
       and rc.response_status = 'accepted'
       and exists (select 1 from public.consents c where c.user_id = rc.donor_id and c.withdrawn_at is null)
       and exists (select 1 from public.profiles p where p.id = rc.donor_id and p.account_status = 'active');
end;
$$;

create or replace function public.withdraw_consent(p_consent_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    owner_id uuid;
begin
    select c.user_id into owner_id from public.consents c where c.id = p_consent_id;
    if owner_id is null or owner_id <> auth.uid() then
        raise exception 'Consent record not found or not owned by user';
    end if;
    update public.consents set withdrawn_at = coalesce(withdrawn_at, now()) where id = p_consent_id;
    update public.donor_profiles set willing_to_donate = false, updated_at = now() where user_id = owner_id;
end;
$$;

create or replace function public.register_for_activity(p_activity_id uuid)
returns public.activity_registrations
language plpgsql
security definer
set search_path = ''
as $$
declare
    event_row public.donor_activities;
    registration public.activity_registrations;
    current_count integer;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;
    select * into event_row from public.donor_activities where id = p_activity_id and status = 'approved' for update;
    if event_row.id is null then
        raise exception 'Activity is not available for registration';
    end if;
    select count(*)::integer into current_count
      from public.activity_registrations ar
     where ar.activity_id = p_activity_id and ar.status = 'registered';
    if current_count >= event_row.quota then
        raise exception 'Activity quota is full';
    end if;
    insert into public.activity_registrations (activity_id, student_id)
    values (p_activity_id, auth.uid())
    on conflict (activity_id, student_id)
    do update set status = 'registered', registered_at = now()
    returning * into registration;
    return registration;
end;
$$;

create or replace function public.record_admin_action(p_action text, p_entity_name text, p_entity_id text default null, p_metadata jsonb default '{}'::jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    new_log_id bigint;
begin
    if not public.is_admin() then
        raise exception 'Admin role required';
    end if;
    insert into public.admin_audit_log (actor_id, action, entity_name, entity_id, metadata)
    values (auth.uid(), p_action, p_entity_name, p_entity_id, coalesce(p_metadata, '{}'::jsonb))
    returning id into new_log_id;
    return new_log_id;
end;
$$;

-- Enable row-level security before granting app roles access.
alter table public.profiles enable row level security;
alter table public.donor_profiles enable row level security;
alter table public.private_contacts enable row level security;
alter table public.consents enable row level security;
alter table public.screening_records enable row level security;
alter table public.blood_requests enable row level security;
alter table public.request_candidates enable row level security;
alter table public.donor_history enable row level security;
alter table public.donor_activities enable row level security;
alter table public.activity_registrations enable row level security;
alter table public.app_settings enable row level security;
alter table public.admin_audit_log enable row level security;

-- Remove default broad grants and add only the application privileges required.
revoke all on public.profiles, public.donor_profiles, public.private_contacts, public.consents,
    public.screening_records, public.blood_requests, public.request_candidates,
    public.donor_history, public.donor_activities, public.activity_registrations,
    public.app_settings, public.admin_audit_log from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (full_name, nim) on public.profiles to authenticated;
grant select on public.donor_profiles to authenticated;
grant update (blood_group, rhesus, willing_to_donate) on public.donor_profiles to authenticated;
grant select, insert, update (whatsapp_number) on public.private_contacts to authenticated;
grant select, insert on public.consents to authenticated;
grant select, insert on public.screening_records to authenticated;
grant select, insert, update on public.blood_requests to authenticated;
grant select, insert on public.request_candidates to authenticated;
grant select on public.donor_history to authenticated;
grant insert on public.donor_history to authenticated;
grant select, insert, update on public.donor_activities to authenticated;
grant select on public.activity_registrations to authenticated;
grant select, insert, update on public.app_settings to authenticated;
grant select on public.admin_audit_log to authenticated;
grant usage, select on sequence public.admin_audit_log_id_seq to authenticated;

-- Profiles: own profile by default; admins can review campus accounts.
drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());

-- Donor matching metadata is visible to the owner and authorized admins, never contact data.
drop policy if exists donor_profiles_read_self_or_admin on public.donor_profiles;
create policy donor_profiles_read_self_or_admin on public.donor_profiles for select to authenticated
using (
    user_id = auth.uid()
    or (public.is_admin() and exists (select 1 from public.consents c where c.user_id = user_id and c.withdrawn_at is null))
);
drop policy if exists donor_profiles_insert_self on public.donor_profiles;
create policy donor_profiles_insert_self on public.donor_profiles for insert to authenticated
with check (user_id = auth.uid());
drop policy if exists donor_profiles_update_self on public.donor_profiles;
create policy donor_profiles_update_self on public.donor_profiles for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A donor can read/write only their own private contact row; admins use the accepted-response RPC.
drop policy if exists private_contacts_owner_only on public.private_contacts;
create policy private_contacts_owner_only on public.private_contacts for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Consent records are append-only for users. Withdrawal is handled through a controlled function.
drop policy if exists consents_read_self_or_admin on public.consents;
create policy consents_read_self_or_admin on public.consents for select to authenticated
using (user_id = auth.uid() or public.is_admin());
drop policy if exists consents_insert_self on public.consents;
create policy consents_insert_self on public.consents for insert to authenticated
with check (user_id = auth.uid());

-- Screening records are private to the account owner; the admin sees only donor_profiles.screening_state.
drop policy if exists screenings_owner_read on public.screening_records;
create policy screenings_owner_read on public.screening_records for select to authenticated
using (user_id = auth.uid());
drop policy if exists screenings_owner_insert_with_consent on public.screening_records;
create policy screenings_owner_insert_with_consent on public.screening_records for insert to authenticated
with check (
    user_id = auth.uid()
    and exists (select 1 from public.consents c where c.user_id = auth.uid() and c.withdrawn_at is null)
);

-- Only admins manage blood requests; no requester account is created in the MVP.
drop policy if exists requests_admin_all on public.blood_requests;
create policy requests_admin_all on public.blood_requests for all to authenticated
using (public.is_admin()) with check (public.is_admin());

-- Admins issue notifications/candidates. A donor can view only their own candidate row.
drop policy if exists candidates_read_admin_or_owner on public.request_candidates;
create policy candidates_read_admin_or_owner on public.request_candidates for select to authenticated
using (public.is_admin() or donor_id = auth.uid());
drop policy if exists candidates_insert_admin on public.request_candidates;
create policy candidates_insert_admin on public.request_candidates for insert to authenticated
with check (public.is_admin());

-- Donors see only their own history; admins record verified outcomes.
drop policy if exists donor_history_read_owner_or_admin on public.donor_history;
create policy donor_history_read_owner_or_admin on public.donor_history for select to authenticated
using (donor_id = auth.uid() or public.is_admin());
drop policy if exists donor_history_insert_admin on public.donor_history;
create policy donor_history_insert_admin on public.donor_history for insert to authenticated
with check (public.is_admin() and recorded_by = auth.uid());

-- Organizers can manage their own submissions; students see only approved activities.
drop policy if exists activities_read_approved_owner_admin on public.donor_activities;
create policy activities_read_approved_owner_admin on public.donor_activities for select to authenticated
using (status = 'approved' or organizer_id = auth.uid() or public.is_admin());
drop policy if exists activities_insert_organizer_or_admin on public.donor_activities;
create policy activities_insert_organizer_or_admin on public.donor_activities for insert to authenticated
with check (organizer_id = auth.uid() and public.current_app_role() in ('organizer', 'admin'));
drop policy if exists activities_update_owner_or_admin on public.donor_activities;
create policy activities_update_owner_or_admin on public.donor_activities for update to authenticated
using ((organizer_id = auth.uid() and public.current_app_role() = 'organizer') or public.is_admin())
with check ((organizer_id = auth.uid() and public.current_app_role() = 'organizer') or public.is_admin());

drop policy if exists registrations_read_owner_organizer_admin on public.activity_registrations;
create policy registrations_read_owner_organizer_admin on public.activity_registrations for select to authenticated
using (
    student_id = auth.uid()
    or public.is_admin()
    or exists (select 1 from public.donor_activities a where a.id = activity_id and a.organizer_id = auth.uid())
);

-- Only admins can read/update system settings; public app users have no direct writes to audit logs.
drop policy if exists settings_admin_all on public.app_settings;
create policy settings_admin_all on public.app_settings for all to authenticated
using (public.is_admin()) with check (public.is_admin());
drop policy if exists audit_admin_read on public.admin_audit_log;
create policy audit_admin_read on public.admin_audit_log for select to authenticated
using (public.is_admin());

-- Controlled RPCs keep sensitive actions tied to the authenticated actor.
revoke all on function public.current_app_role() from public;
revoke all on function public.is_admin() from public;
revoke all on function public.set_donor_verification(uuid, boolean, text) from public;
revoke all on function public.respond_to_candidate(uuid, text) from public;
revoke all on function public.get_accepted_donor_contact(uuid) from public;
revoke all on function public.withdraw_consent(uuid) from public;
revoke all on function public.register_for_activity(uuid) from public;
revoke all on function public.record_admin_action(text, text, text, jsonb) from public;
grant execute on function public.current_app_role() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.set_donor_verification(uuid, boolean, text) to authenticated;
grant execute on function public.respond_to_candidate(uuid, text) to authenticated;
grant execute on function public.get_accepted_donor_contact(uuid) to authenticated;
grant execute on function public.withdraw_consent(uuid) to authenticated;
grant execute on function public.register_for_activity(uuid) to authenticated;
grant execute on function public.record_admin_action(text, text, text, jsonb) to authenticated;

-- Updated timestamps are maintained by the database, not the browser.
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists donor_profiles_set_updated_at on public.donor_profiles;
create trigger donor_profiles_set_updated_at before update on public.donor_profiles
for each row execute function public.set_updated_at();
drop trigger if exists requests_set_updated_at on public.blood_requests;
create trigger requests_set_updated_at before update on public.blood_requests
for each row execute function public.set_updated_at();
drop trigger if exists activities_set_updated_at on public.donor_activities;
create trigger activities_set_updated_at before update on public.donor_activities
for each row execute function public.set_updated_at();

insert into public.app_settings (setting_key, setting_value)
values
    ('donor_interval_days', '60'::jsonb),
    ('monthly_notification_limit', '3'::jsonb),
    ('blood_matching_policy', '"pending_udd_pmi_validation"'::jsonb)
on conflict (setting_key) do nothing;

commit;
