-- JulNow ERD v3: database julnow_auth
-- Reference only. Each table goes into a Flyway file when its task starts.

-- Every account: tenant, owner and admin [P1] FR-02, FR-03, FR-12, FR-18
CREATE TABLE users (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name            VARCHAR(100) NOT NULL,
    email                VARCHAR(150) NOT NULL UNIQUE,
    phone                VARCHAR(25) UNIQUE,
    password_hash        VARCHAR(255) NOT NULL,
    role                 VARCHAR(20) NOT NULL DEFAULT 'TENANT',
    status               VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    email_verified       BOOLEAN NOT NULL DEFAULT false,
    phone_verified       BOOLEAN NOT NULL DEFAULT false,
    avatar_url           VARCHAR(500),
    location             VARCHAR(150),
    bio                  TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at        TIMESTAMPTZ,
    admin_role_code      VARCHAR(30),
    CONSTRAINT chk_users_role CHECK (role IN ('TENANT', 'OWNER', 'ADMIN')),
    CONSTRAINT chk_users_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED'))
);
CREATE UNIQUE INDEX users_email_lower_uq ON users (lower(email));

-- One row per user, created with the account [P1] FR-11
CREATE TABLE user_settings (
    user_id              BIGINT PRIMARY KEY,
    language             VARCHAR(5) NOT NULL DEFAULT 'en',
    currency             VARCHAR(3) NOT NULL DEFAULT 'USD',
    dark_mode            BOOLEAN NOT NULL DEFAULT true,
    notify_push          BOOLEAN NOT NULL DEFAULT true,
    notify_email         BOOLEAN NOT NULL DEFAULT true,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_user_settings_language CHECK (language IN ('en', 'km', 'zh')),
    CONSTRAINT chk_user_settings_currency CHECK (currency IN ('USD', 'KHR'))
);

-- 6-digit codes, valid 5 minutes. Only the hash is stored [P1] FR-04, FR-16
CREATE TABLE otp_codes (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id              BIGINT NOT NULL,
    purpose              VARCHAR(20) NOT NULL,
    channel              VARCHAR(10) NOT NULL,
    destination          VARCHAR(150) NOT NULL,
    code_hash            VARCHAR(255) NOT NULL,
    attempts             INT NOT NULL DEFAULT 0,
    expires_at           TIMESTAMPTZ NOT NULL,
    used_at              TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_otp_codes_purpose CHECK (purpose IN ('VERIFY_ACCOUNT', 'RESET_PASSWORD', 'ADMIN_MFA')),
    CONSTRAINT chk_otp_codes_channel CHECK (channel IN ('EMAIL', 'SMS')),
    CONSTRAINT chk_otp_codes_attempts_value CHECK (attempts >= 0)
);
CREATE INDEX idx_otp_codes_user_id_purpose ON otp_codes (user_id, purpose);

-- Login sessions: Remember me, sign out, session timeout [P2] FR-03, FR-16
CREATE TABLE refresh_tokens (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id              BIGINT NOT NULL,
    token_hash           VARCHAR(255) NOT NULL UNIQUE,
    device               VARCHAR(100),
    expires_at           TIMESTAMPTZ NOT NULL,
    revoked_at           TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);

-- Seed data: 3 plans. Settings > Upgrade to Business [P1] FR-12, FR-20
CREATE TABLE plans (
    code                 VARCHAR(10) PRIMARY KEY,
    name                 VARCHAR(50) NOT NULL,
    price_monthly        NUMERIC(10,2) NOT NULL,
    price_yearly         NUMERIC(10,2),
    max_active_listings  INT NOT NULL,
    trial_days           INT NOT NULL DEFAULT 0,
    priority_placement   BOOLEAN NOT NULL DEFAULT false,
    analytics            BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT chk_plans_code CHECK (code IN ('TRIAL', 'STARTER', 'PRO')),
    CONSTRAINT chk_plans_price_monthly_value CHECK (price_monthly >= 0),
    CONSTRAINT chk_plans_max_active_listings_value CHECK (max_active_listings > 0)
);

-- Owner plan. MVP uses Trial only, no real payment [P1] FR-12, FR-20
CREATE TABLE subscriptions (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id              BIGINT NOT NULL,
    plan_code            VARCHAR(10) NOT NULL,
    status               VARCHAR(20) NOT NULL,
    started_at           TIMESTAMPTZ NOT NULL,
    current_period_end   TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    grace_until          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_subscriptions_status CHECK (status IN ('TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED')),
    CONSTRAINT chk_subscriptions_1 CHECK (current_period_end > started_at)
);
CREATE INDEX idx_subscriptions_user_id_status ON subscriptions (user_id, status);

-- Subscription payments and retries. Needed for revenue KPIs [Later] FR-17, FR-20
CREATE TABLE invoices (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_id      BIGINT NOT NULL,
    amount               NUMERIC(10,2) NOT NULL,
    status               VARCHAR(10) NOT NULL,
    attempt_count        SMALLINT NOT NULL DEFAULT 0,
    period_start         DATE NOT NULL,
    period_end           DATE NOT NULL,
    paid_at              TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_invoices_amount_value CHECK (amount >= 0),
    CONSTRAINT chk_invoices_status CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    CONSTRAINT chk_invoices_attempt_count_value CHECK (attempt_count between 0 and 3)
);
CREATE INDEX idx_invoices_subscription_id ON invoices (subscription_id);
CREATE INDEX idx_invoices_status_created_at ON invoices (status, created_at);

-- View profile > Block [P3] FR-11
CREATE TABLE user_blocks (
    blocker_id           BIGINT NOT NULL,
    blocked_id           BIGINT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT chk_user_blocks_1 CHECK (blocker_id <> blocked_id)
);

-- Report a user or listing; Admin Reports & Risk [P3] FR-11, FR-21
CREATE TABLE reports (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id          BIGINT NOT NULL,
    target_type          VARCHAR(10) NOT NULL,
    target_id            BIGINT NOT NULL,
    reason               VARCHAR(20) NOT NULL,
    details              TEXT,
    status               VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    action_taken         VARCHAR(20),
    handled_by           BIGINT,
    resolution_note      TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reports_target_type CHECK (target_type IN ('USER', 'LISTING')),
    CONSTRAINT chk_reports_reason CHECK (reason IN ('SCAM', 'FAKE_PHOTOS', 'WRONG_PRICE', 'ABUSE', 'OTHER')),
    CONSTRAINT chk_reports_status CHECK (status IN ('OPEN', 'REVIEWING', 'ESCALATED', 'RESOLVED', 'DISMISSED')),
    CONSTRAINT chk_reports_action_taken CHECK (action_taken IN ('NONE', 'PAUSE_LISTING', 'SUSPEND_OWNER'))
);
CREATE INDEX idx_reports_status_created_at ON reports (status, created_at);

-- Admin roles and permissions [P3] FR-22
CREATE TABLE admin_roles (
    code                 VARCHAR(30) PRIMARY KEY,
    name                 VARCHAR(50) NOT NULL,
    permissions          TEXT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Every admin action. Never updated or deleted [P3] FR-22
CREATE TABLE audit_logs (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    admin_id             BIGINT NOT NULL,
    action               VARCHAR(50) NOT NULL,
    target_type          VARCHAR(20) NOT NULL,
    target_id            BIGINT NOT NULL,
    detail               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_audit_logs_target_type CHECK (target_type IN ('USER', 'LISTING', 'BOOKING', 'SUBSCRIPTION', 'REPORT'))
);
CREATE INDEX idx_audit_logs_target_type_target_id ON audit_logs (target_type, target_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs (created_at);

-- Platform settings (Admin > Settings) [Later] FR-22
CREATE TABLE app_settings (
    key                  VARCHAR(50) PRIMARY KEY,
    value                VARCHAR(255) NOT NULL,
    updated_by           BIGINT,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users ADD CONSTRAINT fk_users_admin_role_code FOREIGN KEY (admin_role_code) REFERENCES admin_roles (code) ON DELETE SET NULL;

ALTER TABLE user_settings ADD CONSTRAINT fk_user_settings_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE otp_codes ADD CONSTRAINT fk_otp_codes_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE refresh_tokens ADD CONSTRAINT fk_refresh_tokens_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_plan_code FOREIGN KEY (plan_code) REFERENCES plans (code);

ALTER TABLE invoices ADD CONSTRAINT fk_invoices_subscription_id FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE CASCADE;

ALTER TABLE user_blocks ADD CONSTRAINT fk_user_blocks_blocker_id FOREIGN KEY (blocker_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE user_blocks ADD CONSTRAINT fk_user_blocks_blocked_id FOREIGN KEY (blocked_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE reports ADD CONSTRAINT fk_reports_reporter_id FOREIGN KEY (reporter_id) REFERENCES users (id) ON DELETE CASCADE;

ALTER TABLE reports ADD CONSTRAINT fk_reports_handled_by FOREIGN KEY (handled_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE audit_logs ADD CONSTRAINT fk_audit_logs_admin_id FOREIGN KEY (admin_id) REFERENCES users (id);

ALTER TABLE app_settings ADD CONSTRAINT fk_app_settings_updated_by FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL;
-- JulNow ERD v3: database julnow_listing
-- Reference only. Each table goes into a Flyway file when its task starts.

-- Seed data: Rental, Stay, Travel [P1] FR-01, FR-05
CREATE TABLE categories (
    id                   SMALLINT PRIMARY KEY,
    code                 VARCHAR(20) NOT NULL UNIQUE,
    name                 VARCHAR(50) NOT NULL,
    icon                 VARCHAR(100),
    sort_order           SMALLINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_categories_code CHECK (code IN ('RENTAL', 'STAY', 'TRAVEL'))
);

-- Seed data: 9 subtypes [P1] FR-01, FR-05
CREATE TABLE subcategories (
    id                   SMALLINT PRIMARY KEY,
    category_id          SMALLINT NOT NULL,
    code                 VARCHAR(20) NOT NULL UNIQUE,
    name                 VARCHAR(50) NOT NULL,
    default_price_unit   VARCHAR(10) NOT NULL,
    CONSTRAINT chk_subcategories_default_price_unit CHECK (default_price_unit IN ('HOUR', 'DAY', 'NIGHT', 'MONTH'))
);

-- Shared fields of every listing [P1] FR-01, FR-05, FR-06, FR-14
CREATE TABLE listings (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id             BIGINT NOT NULL,
    subcategory_id       SMALLINT NOT NULL,
    title                VARCHAR(150) NOT NULL,
    description          TEXT NOT NULL,
    price                NUMERIC(12,2) NOT NULL,
    price_unit           VARCHAR(10) NOT NULL,
    discount_type        VARCHAR(10) NOT NULL DEFAULT 'NONE',
    discount_value       NUMERIC(12,2) NOT NULL DEFAULT 0,
    fee_type             VARCHAR(10) NOT NULL DEFAULT 'NONE',
    fee_value            NUMERIC(12,2) NOT NULL DEFAULT 0,
    max_guests           SMALLINT,
    province             VARCHAR(50) NOT NULL,
    area                 VARCHAR(100),
    address              VARCHAR(255),
    latitude             NUMERIC(9,6),
    longitude            NUMERIC(9,6),
    contact_name         VARCHAR(100),
    contact_phone        VARCHAR(60),
    contact_email        VARCHAR(150),
    contact_telegram     VARCHAR(150),
    status               VARCHAR(20) NOT NULL DEFAULT 'PENDING_REVIEW',
    availability         VARCHAR(10) NOT NULL DEFAULT 'AVAILABLE',
    is_featured          BOOLEAN NOT NULL DEFAULT false,
    view_count           INT NOT NULL DEFAULT 0,
    rating_avg           NUMERIC(2,1) NOT NULL DEFAULT 0,
    rating_count         INT NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_listings_price_value CHECK (price >= 0),
    CONSTRAINT chk_listings_price_unit CHECK (price_unit IN ('HOUR', 'DAY', 'NIGHT', 'MONTH')),
    CONSTRAINT chk_listings_discount_type CHECK (discount_type IN ('NONE', 'PERCENT', 'AMOUNT')),
    CONSTRAINT chk_listings_discount_value_value CHECK (discount_value >= 0),
    CONSTRAINT chk_listings_fee_type CHECK (fee_type IN ('NONE', 'PERCENT', 'AMOUNT')),
    CONSTRAINT chk_listings_fee_value_value CHECK (fee_value >= 0),
    CONSTRAINT chk_listings_max_guests_value CHECK (max_guests > 0),
    CONSTRAINT chk_listings_status CHECK (status IN ('PENDING_REVIEW', 'ACTIVE', 'CHANGES_REQUESTED', 'REJECTED', 'PAUSED')),
    CONSTRAINT chk_listings_availability CHECK (availability IN ('AVAILABLE', 'OCCUPIED')),
    CONSTRAINT chk_listings_view_count_value CHECK (view_count >= 0),
    CONSTRAINT chk_listings_rating_avg_value CHECK (rating_avg between 0 and 5),
    CONSTRAINT chk_listings_rating_count_value CHECK (rating_count >= 0),
    CONSTRAINT chk_listings_1 CHECK (discount_type <> 'PERCENT' or discount_value <= 100),
    CONSTRAINT chk_listings_2 CHECK (fee_type <> 'PERCENT' or fee_value <= 100)
);
CREATE INDEX idx_listings_status_subcategory_id ON listings (status, subcategory_id);
CREATE INDEX idx_listings_province_area ON listings (province, area);
CREATE INDEX idx_listings_owner_id ON listings (owner_id);
CREATE INDEX idx_listings_status_price ON listings (status, price);

-- Only for RENTAL and STAY listings [P1] FR-06, FR-14
CREATE TABLE property_details (
    listing_id           BIGINT PRIMARY KEY,
    bedrooms             SMALLINT,
    bathrooms            SMALLINT,
    size_m2              NUMERIC(8,2),
    floor                VARCHAR(20),
    facing               VARCHAR(20),
    furnished            VARCHAR(10),
    building_age_years   SMALLINT,
    pet_friendly         BOOLEAN,
    bed_type             VARCHAR(50),
    CONSTRAINT chk_property_details_bedrooms_value CHECK (bedrooms >= 0),
    CONSTRAINT chk_property_details_bathrooms_value CHECK (bathrooms >= 0),
    CONSTRAINT chk_property_details_size_m2_value CHECK (size_m2 > 0),
    CONSTRAINT chk_property_details_furnished CHECK (furnished IN ('FULL', 'PARTLY', 'NONE'))
);

-- Only for TRAVEL listings [P1] FR-06, FR-14
CREATE TABLE vehicle_details (
    listing_id           BIGINT PRIMARY KEY,
    make                 VARCHAR(50),
    model                VARCHAR(50),
    year                 SMALLINT,
    spec                 VARCHAR(255)
);

-- Up to 10 photos, sort_order 0 is the cover [P1] FR-06, FR-14
CREATE TABLE listing_photos (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT NOT NULL,
    url                  VARCHAR(500) NOT NULL,
    content_hash         VARCHAR(64),
    sort_order           SMALLINT NOT NULL,
    CONSTRAINT chk_listing_photos_sort_order_value CHECK (sort_order between 0 and 9),
    UNIQUE (listing_id, sort_order)
);
CREATE INDEX idx_listing_photos_content_hash ON listing_photos (content_hash);

-- Seed data: Wifi, AC, Pool ... [P1] FR-06
CREATE TABLE amenities (
    id                   SMALLINT PRIMARY KEY,
    name                 VARCHAR(50) NOT NULL UNIQUE,
    icon                 VARCHAR(100)
);

-- Which amenities a listing has [P1] FR-06, FR-14
CREATE TABLE listing_amenities (
    listing_id           BIGINT NOT NULL,
    amenity_id           SMALLINT NOT NULL,
    PRIMARY KEY (listing_id, amenity_id)
);

-- Listing detail > Location > Nearby places [P2] FR-06
CREATE TABLE nearby_places (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT NOT NULL,
    name                 VARCHAR(100) NOT NULL,
    distance_km          NUMERIC(5,2),
    travel_minutes       SMALLINT,
    CONSTRAINT chk_nearby_places_distance_km_value CHECK (distance_km >= 0)
);
CREATE INDEX idx_nearby_places_listing_id ON nearby_places (listing_id);

-- Saved listings, grouped by category [P2] FR-07
CREATE TABLE wishlists (
    user_id              BIGINT NOT NULL,
    listing_id           BIGINT NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, listing_id)
);
CREATE INDEX idx_wishlists_listing_id ON wishlists (listing_id);

-- Review & Rating on listing detail [P2] FR-06
CREATE TABLE reviews (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT NOT NULL,
    user_id              BIGINT NOT NULL,
    booking_id           BIGINT,
    rating               SMALLINT NOT NULL,
    comment              TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reviews_rating_value CHECK (rating between 1 and 5),
    UNIQUE (listing_id, user_id)
);
CREATE UNIQUE INDEX idx_reviews_booking_id ON reviews (booking_id);

-- System checks before publishing [P1] FR-19
CREATE TABLE listing_flags (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT NOT NULL,
    flag_type            VARCHAR(20) NOT NULL,
    detail               VARCHAR(255),
    resolved             BOOLEAN NOT NULL DEFAULT false,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_listing_flags_flag_type CHECK (flag_type IN ('DUPLICATE_PHOTOS', 'PRICE_TOO_HIGH', 'BANNED_PHONE'))
);
CREATE INDEX idx_listing_flags_listing_id_resolved ON listing_flags (listing_id, resolved);

-- Admin decisions on listings [P1] FR-19
CREATE TABLE moderation_logs (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    listing_id           BIGINT NOT NULL,
    admin_id             BIGINT NOT NULL,
    action               VARCHAR(20) NOT NULL,
    reason               TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_moderation_logs_action CHECK (action IN ('APPROVE', 'REQUEST_CHANGES', 'REJECT', 'PAUSE'))
);
CREATE INDEX idx_moderation_logs_listing_id ON moderation_logs (listing_id);

-- Views per listing per day, for the Owner Dashboard chart [P2] FR-13
CREATE TABLE listing_view_stats (
    listing_id           BIGINT NOT NULL,
    day                  DATE NOT NULL,
    views                INT NOT NULL DEFAULT 0,
    PRIMARY KEY (listing_id, day),
    CONSTRAINT chk_listing_view_stats_views_value CHECK (views >= 0)
);

ALTER TABLE subcategories ADD CONSTRAINT fk_subcategories_category_id FOREIGN KEY (category_id) REFERENCES categories (id);

ALTER TABLE listings ADD CONSTRAINT fk_listings_subcategory_id FOREIGN KEY (subcategory_id) REFERENCES subcategories (id);

ALTER TABLE property_details ADD CONSTRAINT fk_property_details_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE vehicle_details ADD CONSTRAINT fk_vehicle_details_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE listing_photos ADD CONSTRAINT fk_listing_photos_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE listing_amenities ADD CONSTRAINT fk_listing_amenities_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE listing_amenities ADD CONSTRAINT fk_listing_amenities_amenity_id FOREIGN KEY (amenity_id) REFERENCES amenities (id);

ALTER TABLE nearby_places ADD CONSTRAINT fk_nearby_places_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE wishlists ADD CONSTRAINT fk_wishlists_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE reviews ADD CONSTRAINT fk_reviews_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE listing_flags ADD CONSTRAINT fk_listing_flags_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE moderation_logs ADD CONSTRAINT fk_moderation_logs_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;

ALTER TABLE listing_view_stats ADD CONSTRAINT fk_listing_view_stats_listing_id FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE;
-- JulNow ERD v3: database julnow_booking
-- Reference only. Each table goes into a Flyway file when its task starts.

-- Booking with price snapshot, so later listing edits do not change it [P1] FR-09, FR-10, FR-13
CREATE TABLE bookings (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_code         VARCHAR(20) NOT NULL UNIQUE,
    listing_id           BIGINT NOT NULL,
    tenant_id            BIGINT NOT NULL,
    owner_id             BIGINT NOT NULL,
    listing_title        VARCHAR(150) NOT NULL,
    category_code        VARCHAR(20) NOT NULL,
    unit_label           VARCHAR(50),
    start_date           DATE NOT NULL,
    end_date             DATE NOT NULL,
    adults               SMALLINT NOT NULL DEFAULT 1,
    children             SMALLINT NOT NULL DEFAULT 0,
    guest_name           VARCHAR(100) NOT NULL,
    guest_email          VARCHAR(150),
    guest_phone          VARCHAR(25),
    unit_price           NUMERIC(12,2) NOT NULL,
    price_unit           VARCHAR(10) NOT NULL,
    quantity             SMALLINT NOT NULL,
    subtotal             NUMERIC(12,2) NOT NULL,
    discount_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    taxes_fees           NUMERIC(12,2) NOT NULL DEFAULT 0,
    total                NUMERIC(12,2) NOT NULL,
    payment_method       VARCHAR(20) NOT NULL DEFAULT 'PAY_AT_PROPERTY',
    payment_status       VARCHAR(10) NOT NULL DEFAULT 'UNPAID',
    policy_snapshot      TEXT,
    status               VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED',
    checked_in_at        TIMESTAMPTZ,
    cancelled_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_bookings_category_code CHECK (category_code IN ('RENTAL', 'STAY', 'TRAVEL')),
    CONSTRAINT chk_bookings_adults_value CHECK (adults >= 1),
    CONSTRAINT chk_bookings_children_value CHECK (children >= 0),
    CONSTRAINT chk_bookings_unit_price_value CHECK (unit_price >= 0),
    CONSTRAINT chk_bookings_price_unit CHECK (price_unit IN ('HOUR', 'DAY', 'NIGHT', 'MONTH')),
    CONSTRAINT chk_bookings_quantity_value CHECK (quantity > 0),
    CONSTRAINT chk_bookings_subtotal_value CHECK (subtotal >= 0),
    CONSTRAINT chk_bookings_discount_amount_value CHECK (discount_amount >= 0),
    CONSTRAINT chk_bookings_taxes_fees_value CHECK (taxes_fees >= 0),
    CONSTRAINT chk_bookings_total_value CHECK (total >= 0),
    CONSTRAINT chk_bookings_payment_method CHECK (payment_method IN ('PAY_AT_PROPERTY', 'KHQR')),
    CONSTRAINT chk_bookings_payment_status CHECK (payment_status IN ('UNPAID', 'PAID', 'REFUNDED')),
    CONSTRAINT chk_bookings_status CHECK (status IN ('PENDING', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT chk_bookings_1 CHECK (end_date >= start_date),
    CONSTRAINT chk_bookings_2 CHECK (total = subtotal - discount_amount + taxes_fees)
);
CREATE INDEX idx_bookings_tenant_id ON bookings (tenant_id);
CREATE INDEX idx_bookings_owner_id_created_at ON bookings (owner_id, created_at);
CREATE INDEX idx_bookings_listing_id_start_date_end_date ON bookings (listing_id, start_date, end_date);

-- Chat between tenant and owner [P3] FR-08
CREATE TABLE conversations (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type                 VARCHAR(10) NOT NULL DEFAULT 'DIRECT',
    name                 VARCHAR(100),
    listing_id           BIGINT,
    created_by           BIGINT NOT NULL,
    last_message_at      TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_conversations_type CHECK (type IN ('DIRECT', 'GROUP'))
);

-- Who is in each chat [P3] FR-08
CREATE TABLE conversation_members (
    conversation_id      BIGINT NOT NULL,
    user_id              BIGINT NOT NULL,
    last_read_at         TIMESTAMPTZ,
    joined_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);
CREATE INDEX idx_conversation_members_user_id ON conversation_members (user_id);

-- Chat messages, text or a shared listing card [P3] FR-08
CREATE TABLE messages (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id      BIGINT NOT NULL,
    sender_id            BIGINT NOT NULL,
    body                 TEXT,
    shared_listing_id    BIGINT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_messages_1 CHECK (body is not null or shared_listing_id is not null)
);
CREATE INDEX idx_messages_conversation_id_created_at ON messages (conversation_id, created_at);

-- In-app notifications. Other services create them through the API [P2] FR-10
CREATE TABLE notifications (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id              BIGINT NOT NULL,
    type                 VARCHAR(40) NOT NULL,
    title                VARCHAR(150) NOT NULL,
    body                 VARCHAR(500),
    related_type         VARCHAR(20),
    related_id           BIGINT,
    is_read              BOOLEAN NOT NULL DEFAULT false,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_notifications_related_type CHECK (related_type IN ('BOOKING', 'LISTING', 'CONVERSATION'))
);
CREATE INDEX idx_notifications_user_id_is_read ON notifications (user_id, is_read);

-- Tenant Roster: long-term tenants of an owner [P3] FR-15
CREATE TABLE leases (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id             BIGINT NOT NULL,
    listing_id           BIGINT NOT NULL,
    tenant_user_id       BIGINT,
    tenant_name          VARCHAR(100) NOT NULL,
    unit_label           VARCHAR(50),
    monthly_rent         NUMERIC(12,2) NOT NULL,
    lease_start          DATE NOT NULL,
    lease_end            DATE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_leases_monthly_rent_value CHECK (monthly_rent >= 0),
    CONSTRAINT chk_leases_1 CHECK (lease_end is null or lease_end >= lease_start)
);
CREATE INDEX idx_leases_owner_id ON leases (owner_id);

-- Monthly rent bills sent by KHQR [Later] FR-15
CREATE TABLE rent_bills (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lease_id             BIGINT NOT NULL,
    period_month         DATE NOT NULL,
    amount               NUMERIC(12,2) NOT NULL,
    status               VARCHAR(10) NOT NULL DEFAULT 'UNPAID',
    khqr_payload         TEXT,
    paid_at              TIMESTAMPTZ,
    CONSTRAINT chk_rent_bills_amount_value CHECK (amount >= 0),
    CONSTRAINT chk_rent_bills_status CHECK (status IN ('UNPAID', 'PAID', 'REFUNDED')),
    UNIQUE (lease_id, period_month)
);

ALTER TABLE conversation_members ADD CONSTRAINT fk_conversation_members_conversation_id FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE;

ALTER TABLE messages ADD CONSTRAINT fk_messages_conversation_id FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE;

ALTER TABLE rent_bills ADD CONSTRAINT fk_rent_bills_lease_id FOREIGN KEY (lease_id) REFERENCES leases (id) ON DELETE CASCADE;
