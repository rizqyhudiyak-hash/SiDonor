-- SiDonor initial schema for Supabase/Postgres
-- Apply through Supabase SQL Editor or the Supabase CLI.
-- Sensitive screens/contact data are owner-only; admin contact access is gated by an accepted response.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null default '',
    nim text unique,
    faculty text,
    role text not null default 'student' check (role in ('student', 'organizer', 'admin')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.consents (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    statement_version text not null,
    accepted_at timestamptz not null default now(),
    withdrawn_at timestamptz,
    created_at timestamptz not null default now(),
    constraint consents_withdrawal_after_acceptance check (withdrawn_at is null or withdrawn_at >= accepted_at)
);
create index if not exists consents_user_active_idx on public.consents(user_id, accepted_at desc) where withdrawn_at is null;

create table if not exists public.donor_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    blood_group text check (blood_group is null or blood_group in ('A', 'B', 'AB', 'O')),
    rhesus text check (rhesus is null or rhesus in ('+', '-')),
    blood_group_verified boolean not null default false,
    donor_opt_in boolean not null default false,
    preliminary_eligible boolean not null default false,
    next_eligible_on date,
    verified_by uuid references public.profiles(id) on delete set null,
    verified_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists donor_profiles_match_idx on public.donor_profiles(blood_group, rhesus, preliminary_eligible, donor_opt_in);
create index if not exists donor_profiles_next_eligible_idx on public.donor_profiles(next_eligible_on);

create table if not exists public.screenings (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    age_years smallint not null check (age_years between 1 and 120),
    weight_kg numeric(5,2) not null check (weight_kg > 0 and weight_kg < 400),
    needs_medical_review boolean not null,
    preliminary_result text not null check (preliminary_result in ('preliminarily_eligible', 'not_in_range', 'needs_review')),
    created_at timestamptz not null default now()
);
create index if not exists screenings_user_created_idx on public.screenings(user_id, created_at desc);

create table if not exists public.blood_requests (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references public.profiles(id),
    blood_group text not null check (blood_group in ('A', 'B', 'AB', 'O')),
    rhesus text not null check (rhesus in ('+', '-')),
    bags_needed smallint not null check (bags_needed between 1 and 20),
    location text not null,
    urgency text not null check (urgency in ('emergency', 'planned')),
    requester_name text not null,
    requester_phone text not null,
    requester_verified boolean not null default false,
    status text not null default 'pending_verification' check (status in ('pending_verification', 'open', 'fulfilled', 'closed', 'expired')),
    created_at timestamptz not null default now(),
    expires_at timestamptz
);
create index if not exists blood_requests_status_created_idx on public.blood_requests(status, created_at desc);

create table if not exists public.request_candidates (
    id uuid primary key default gen_random_uuid(),
    request_id uuid not null references public.blood_requests(id) on delete cascade,
    donor_id uuid not null references public.profiles(id) on delete cascade,
    response_status text not null default 'pending' check (response_status in ('pending', 'willing', 'unavailable', 'expired')),
    channel text not null default 'in_app' check (channel in ('whatsapp', 'in_app')),
    notified_at timestamptz,
    responded_at timestamptz,
    created_at timestamptz not null default now(),
    unique (request_id, donor_id),
    constraint candidate_response_time_check check ((response_status = 'pending' and responded_at is null) or (response_status <> 'pending'))
);
create index if not exists request_candidates_donor_status_idx on public.request_candidates(donor_id, response_status);

create table if not exists public.donor_history (
    id uuid primary key default gen_random_uuid(),
    donor_id uuid not null references public.profiles(id) on delete cascade,
    blood_request_id uuid references public.blood_requests(id) on delete set null,
    donation_date date not null,
    outcome text not null check (outcome in ('successful', 'screening_failed')),
    failure_reason text,
    created_by uuid not null references public.profiles(id),
    created_at timestamptz not null default now(),
    constraint failure_reason_only_on_failed check (outcome = 'screening_failed' or failure_reason is null)
);
create index if not exists donor_history_donor_date_idx on public.donor_history(donor_id, donation_date desc);

create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references public.profiles(id),
    title text not null,
    event_date timestamptz not null,
    location text not null,
    capacity integer not null check (capacity > 0),
    partner_name text,
    status text not null default 'pending_review' check (status in ('pending_review', 'published', 'rejected', 'closed')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists events_public_date_idx on public.events(event_date) where status = 'published';

create table if not exists public.event_registrations (
    id uuid primary key default gen_random_uuid(),
    event_id uuid not null references public.events(id) on delete cascade,
    user_id uuid not null references public.profiles(id) on delete cascade,
    registration_status text not null default 'registered' check (registration_status in ('registered', 'cancelled', 'attended', 'no_show')),
    registered_at timestamptz not null default now(),
    unique (event_id, user_id)
);
create index if not exists event_registrations_event_idx on public.event_registrations(event_id, registration_status);

create table if not exists public.system_settings (
    setting_key text primary key,
    setting_value jsonb not null,
    updated_by uuid references public.profiles(id),
    updated_at timestamptz not null default now()
);
insert into public.system_settings(setting_key, setting_value) values
    ('donation_interval_days', '60'::jsonb),
    ('max_notifications_per_donor_month', '3'::jsonb),
    ('blood_matching_mode', '"pending_udd_validation"'::jsonb)
on conflict (setting_key) do nothing;

create table if not exists public.audit_logs (
    id bigint generated always as identity primary key,
    actor_id uuid references public.profiles(id) on delete set null,
    action text not null,
    resource_type text not null,
    resource_id text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);
create index if not exists audit_logs_created_idx on public.audit_logs(created_at desc);
create index if not exists audit_logs_actor_idx on public.audit_logs(actor_id, created_at desc);

-- Contact details are kept out of the API-exposed public schema.
create table if not exists private.donor_contacts (
    user_id uuid primary key references auth.users(id) on delete cascade,
    whatsapp_phone text not null check (length(whatsapp_phone) between 8 and 24),
    contact_email text,
    updated_at timestamptz not null default now()
);

create or replace function public.current_user_has_role(p_role text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = p_role
    );
$$;

create or replace function public.has_active_consent()
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.consents c
        where c.user_id = auth.uid()
          and c.withdrawn_at is null
    );
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.guard_profile_role_change()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
    if new.role is distinct from old.role and not public.current_user_has_role('admin') then
        raise exception 'Only an administrator can change account roles';
    end if;
    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.guard_donor_profile_fields()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
    if not public.current_user_has_role('admin') and (
        new.blood_group_verified is distinct from old.blood_group_verified or
        new.preliminary_eligible is distinct from old.preliminary_eligible or
        new.next_eligible_on is distinct from old.next_eligible_on or
        new.verified_by is distinct from old.verified_by or
        new.verified_at is distinct from old.verified_at
    ) then
        raise exception 'Verification and eligibility fields are system/admin controlled';
    end if;
    new.updated_at := now();
    return new;
end;
$$;

create or replace function public.guard_candidate_response()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
    if not public.current_user_has_role('admin') then
        if new.request_id is distinct from old.request_id or
           new.donor_id is distinct from old.donor_id or
           new.channel is distinct from old.channel or
           new.notified_at is distinct from old.notified_at or
           new.created_at is distinct from old.created_at then
            raise exception 'Donors may only respond to their own invitation';
        end if;
        if old.response_status <> 'pending' or new.response_status not in ('willing', 'unavailable') then
            raise exception 'Invitation response is not changeable';
        end if;
        new.responded_at := now();
    end if;
    return new;
end;
$$;

create or replace function public.create_profile_from_auth_user()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
    insert into public.profiles(id, full_name, nim, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', ''),
        nullif(new.raw_user_meta_data ->> 'nim', ''),
        'student'
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_profile_from_auth_user();

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role before update on public.profiles
for each row execute function public.guard_profile_role_change();
drop trigger if exists donor_profiles_guard_fields on public.donor_profiles;
drop trigger if exists request_candidates_guard_response on public.request_candidates;
create trigger request_candidates_guard_response before update on public.request_candidates
for each row execute function public.guard_candidate_response();
drop trigger if exists donor_profiles_touch_updated_at on public.donor_profiles;
create trigger donor_profiles_touch_updated_at before update on public.donor_profiles
for each row execute function public.touch_updated_at();
drop trigger if exists events_touch_updated_at on public.events;
create trigger events_touch_updated_at before update on public.events
for each row execute function public.touch_updated_at();

create or replace function public.submit_screening(p_age_years smallint, p_weight_kg numeric, p_needs_medical_review boolean)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_result text;
    v_eligible boolean;
begin
    if v_user_id is null then raise exception 'Authentication required'; end if;
    if not public.has_active_consent() then raise exception 'Active data consent required'; end if;
    if p_age_years not between 1 and 120 or p_weight_kg <= 0 or p_weight_kg >= 400 then
        raise exception 'Invalid screening values';
    end if;
    v_eligible := p_age_years between 17 and 65 and p_weight_kg >= 45 and not p_needs_medical_review;
    v_result := case
        when p_needs_medical_review then 'needs_review'
        when p_age_years not between 17 and 65 or p_weight_kg < 45 then 'not_in_range'
        else 'preliminarily_eligible'
    end;
    insert into public.screenings(user_id, age_years, weight_kg, needs_medical_review, preliminary_result)
    values (v_user_id, p_age_years, p_weight_kg, p_needs_medical_review, v_result);
    insert into public.donor_profiles(user_id, preliminary_eligible)
    values (v_user_id, v_eligible)
    on conflict (user_id) do update set preliminary_eligible = excluded.preliminary_eligible;
    return v_result;
end;
$$;

create or replace function public.update_my_donor_contact(p_whatsapp_phone text, p_contact_email text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
    if auth.uid() is null then raise exception 'Authentication required'; end if;
    if not public.has_active_consent() then raise exception 'Active data consent required'; end if;
    if length(p_whatsapp_phone) not between 8 and 24 then raise exception 'Invalid WhatsApp number'; end if;
    insert into private.donor_contacts(user_id, whatsapp_phone, contact_email, updated_at)
    values (auth.uid(), p_whatsapp_phone, p_contact_email, now())
    on conflict (user_id) do update
    set whatsapp_phone = excluded.whatsapp_phone,
        contact_email = excluded.contact_email,
        updated_at = now();
end;
$$;

create or replace function public.get_willing_contact(p_request_id uuid, p_donor_id uuid)
returns table (whatsapp_phone text, contact_email text)
language sql stable security definer
set search_path = ''
as $$
    select c.whatsapp_phone, c.contact_email
    from private.donor_contacts c
    where public.current_user_has_role('admin')
      and c.user_id = p_donor_id
      and exists (
          select 1 from public.request_candidates rc
          where rc.request_id = p_request_id
            and rc.donor_id = p_donor_id
            and rc.response_status = 'willing'
      );
$$;

create or replace function public.admin_verify_blood_group(p_donor_id uuid, p_verified boolean)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
    if not public.current_user_has_role('admin') then raise exception 'Administrator role required'; end if;
    update public.donor_profiles
    set blood_group_verified = p_verified,
        verified_by = case when p_verified then auth.uid() else null end,
        verified_at = case when p_verified then now() else null end,
        updated_at = now()
    where user_id = p_donor_id;
    if not found then raise exception 'Donor profile not found'; end if;
end;
$$;

-- Row Level Security: deny by default, then grant only the paths required by the PRD.
alter table public.profiles enable row level security;
alter table public.consents enable row level security;
alter table public.donor_profiles enable row level security;
alter table public.screenings enable row level security;
alter table public.blood_requests enable row level security;
alter table public.request_candidates enable row level security;
alter table public.donor_history enable row level security;
alter table public.events enable row level security;
alter table public.event_registrations enable row level security;
alter table public.system_settings enable row level security;
alter table public.audit_logs enable row level security;
alter table private.donor_contacts enable row level security;

-- Profiles: a user sees/edits only their own profile; admins may review campus accounts.
drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.current_user_has_role('admin'));
drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles for update to authenticated
using (id = auth.uid() or public.current_user_has_role('admin'))
with check (id = auth.uid() or public.current_user_has_role('admin'));

-- Consent is user-owned and must be active before donor data can be submitted.
drop policy if exists consents_read_self on public.consents;
create policy consents_read_self on public.consents for select to authenticated using (user_id = auth.uid());
drop policy if exists consents_insert_self on public.consents;
create policy consents_insert_self on public.consents for insert to authenticated
with check (user_id = auth.uid() and withdrawn_at is null);
drop policy if exists consents_withdraw_self on public.consents;
create policy consents_withdraw_self on public.consents for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Donor matching data is visible only to its owner and authorized campus admins.
drop policy if exists donor_profiles_read_owner_admin on public.donor_profiles;
create policy donor_profiles_read_owner_admin on public.donor_profiles for select to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'));
drop policy if exists donor_profiles_insert_owner on public.donor_profiles;
create policy donor_profiles_insert_owner on public.donor_profiles for insert to authenticated
with check (user_id = auth.uid() and public.has_active_consent());
drop policy if exists donor_profiles_update_owner_admin on public.donor_profiles;
create policy donor_profiles_update_owner_admin on public.donor_profiles for update to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'))
with check (user_id = auth.uid() or public.current_user_has_role('admin'));

-- Detailed screening answers are strictly private to the donor; writes go through the RPC above.
drop policy if exists screenings_read_owner on public.screenings;
create policy screenings_read_owner on public.screenings for select to authenticated using (user_id = auth.uid());

-- Blood requests and requester contact details are admin-only.
drop policy if exists blood_requests_admin_all on public.blood_requests;
create policy blood_requests_admin_all on public.blood_requests for all to authenticated
using (public.current_user_has_role('admin')) with check (public.current_user_has_role('admin'));

-- Admins manage invitations; donors can see/respond only to their own invitations.
drop policy if exists request_candidates_admin_all on public.request_candidates;
create policy request_candidates_admin_all on public.request_candidates for all to authenticated
using (public.current_user_has_role('admin')) with check (public.current_user_has_role('admin'));
drop policy if exists request_candidates_donor_read on public.request_candidates;
create policy request_candidates_donor_read on public.request_candidates for select to authenticated
using (donor_id = auth.uid());
drop policy if exists request_candidates_donor_respond on public.request_candidates;
create policy request_candidates_donor_respond on public.request_candidates for update to authenticated
using (donor_id = auth.uid() and response_status = 'pending')
with check (donor_id = auth.uid() and response_status in ('willing', 'unavailable'));

-- Donation history: donor can read their own history; only admins record outcomes.
drop policy if exists donor_history_read_owner_admin on public.donor_history;
create policy donor_history_read_owner_admin on public.donor_history for select to authenticated
using (donor_id = auth.uid() or public.current_user_has_role('admin'));
drop policy if exists donor_history_admin_all on public.donor_history;
create policy donor_history_admin_all on public.donor_history for all to authenticated
using (public.current_user_has_role('admin')) with check (public.current_user_has_role('admin'));

-- Published events are public; organizers manage their own pending submissions, admins verify/publish.
drop policy if exists events_read_published on public.events;
create policy events_read_published on public.events for select to anon, authenticated using (status = 'published');
drop policy if exists events_owner_admin_read on public.events;
create policy events_owner_admin_read on public.events for select to authenticated
using (created_by = auth.uid() or public.current_user_has_role('admin'));
drop policy if exists events_owner_insert_pending on public.events;
create policy events_owner_insert_pending on public.events for insert to authenticated
with check (created_by = auth.uid() and status = 'pending_review' and public.current_user_has_role('organizer'));
drop policy if exists events_owner_update_pending on public.events;
create policy events_owner_update_pending on public.events for update to authenticated
using (created_by = auth.uid() and status = 'pending_review')
with check (created_by = auth.uid() and status = 'pending_review');
drop policy if exists events_admin_all on public.events;
create policy events_admin_all on public.events for all to authenticated
using (public.current_user_has_role('admin')) with check (public.current_user_has_role('admin'));

-- Event sign-ups are private to the participant and event owner/admin.
drop policy if exists registrations_read_owner_or_manager on public.event_registrations;
create policy registrations_read_owner_or_manager on public.event_registrations for select to authenticated
using (user_id = auth.uid() or exists (
    select 1 from public.events e where e.id = event_id
      and (e.created_by = auth.uid() or public.current_user_has_role('admin'))
));
drop policy if exists registrations_insert_self on public.event_registrations;
create policy registrations_insert_self on public.event_registrations for insert to authenticated
with check (user_id = auth.uid() and registration_status = 'registered' and exists (
    select 1 from public.events e where e.id = event_id and e.status = 'published'
));
drop policy if exists registrations_manager_update on public.event_registrations;
create policy registrations_manager_update on public.event_registrations for update to authenticated
using (exists (select 1 from public.events e where e.id = event_id and (e.created_by = auth.uid() or public.current_user_has_role('admin'))))
with check (exists (select 1 from public.events e where e.id = event_id and (e.created_by = auth.uid() or public.current_user_has_role('admin'))));

-- Settings and audit records are admin-readable; clients cannot edit audit entries.
drop policy if exists system_settings_admin_all on public.system_settings;
create policy system_settings_admin_all on public.system_settings for all to authenticated
using (public.current_user_has_role('admin')) with check (public.current_user_has_role('admin'));
drop policy if exists audit_logs_admin_read on public.audit_logs;
create policy audit_logs_admin_read on public.audit_logs for select to authenticated
using (public.current_user_has_role('admin'));

-- Explicit API grants. No direct access is granted to private.donor_contacts.
grant select, update on public.profiles to authenticated;
grant select on public.consents to authenticated;
grant insert (user_id, statement_version) on public.consents to authenticated;
grant update (withdrawn_at) on public.consents to authenticated;
grant select on public.donor_profiles to authenticated;
grant insert (user_id, blood_group, rhesus, donor_opt_in) on public.donor_profiles to authenticated;
grant update (blood_group, rhesus, donor_opt_in) on public.donor_profiles to authenticated;
grant select on public.screenings to authenticated;
grant select, insert, update, delete on public.blood_requests to authenticated;
grant select, insert, update on public.request_candidates to authenticated;
grant select, insert, update on public.donor_history to authenticated;
grant select on public.events to anon, authenticated;
grant insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.event_registrations to authenticated;
grant select, update on public.system_settings to authenticated;
grant select on public.audit_logs to authenticated;

grant execute on function public.current_user_has_role(text) to authenticated;
grant execute on function public.has_active_consent() to authenticated;
grant execute on function public.submit_screening(smallint, numeric, boolean) to authenticated;
grant execute on function public.update_my_donor_contact(text, text) to authenticated;
grant execute on function public.get_willing_contact(uuid, uuid) to authenticated;
grant execute on function public.admin_verify_blood_group(uuid, boolean) to authenticated;
revoke all on function public.current_user_has_role(text) from public, anon;
revoke all on function public.has_active_consent() from public, anon;
revoke all on function public.submit_screening(smallint, numeric, boolean) from public, anon;
revoke all on function public.update_my_donor_contact(text, text) from public, anon;
revoke all on function public.get_willing_contact(uuid, uuid) from public, anon;
revoke all on function public.admin_verify_blood_group(uuid, boolean) from public, anon;

commit;
