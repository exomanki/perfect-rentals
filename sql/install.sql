-- ============================================================
-- perfect_rentals v1.0 — Installation complète
-- Importez ce fichier dans votre base de données MySQL
-- via phpMyAdmin ou en CLI : source install.sql
-- ============================================================

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS `rentals_vehicles` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `model`         VARCHAR(60)  NOT NULL,
    `label`         VARCHAR(120) NOT NULL,
    `category`      VARCHAR(40)  NOT NULL DEFAULT 'sedan',
    `tags`          VARCHAR(255) NOT NULL DEFAULT '',
    `price_per_day` INT UNSIGNED NOT NULL DEFAULT 500,
    `deposit`       INT UNSIGNED NOT NULL DEFAULT 1000,
    `image_url`     VARCHAR(255) NOT NULL DEFAULT '',
    `seats`         TINYINT UNSIGNED NOT NULL DEFAULT 4,
    `trunk`         TINYINT UNSIGNED NOT NULL DEFAULT 40,
    `speed`         TINYINT UNSIGNED NOT NULL DEFAULT 50,
    `handling`      TINYINT UNSIGNED NOT NULL DEFAULT 50,
    `braking`       TINYINT UNSIGNED NOT NULL DEFAULT 50,
    `enabled`       TINYINT(1)   NOT NULL DEFAULT 1,
    `stock`         INT          NOT NULL DEFAULT -1,
    `popularity`    INT UNSIGNED NOT NULL DEFAULT 0,
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rentals_locations` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`             VARCHAR(120) NOT NULL,
    `coords_json`      JSON         NOT NULL,
    `spawnpoints_json` JSON         NOT NULL,
    `return_point_json` JSON        NULL,
    `showroom_json`    JSON         NULL,
    `blip_sprite`      INT          NOT NULL DEFAULT 226,
    `blip_color`       INT          NOT NULL DEFAULT 3,
    `blip_scale`       FLOAT        NOT NULL DEFAULT 0.7,
    `ped_model`        VARCHAR(60)  NULL     DEFAULT 's_m_m_autoshop_02',
    `enabled`          TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rentals_location_vehicles` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `location_id`      INT UNSIGNED NOT NULL,
    `vehicle_id`       INT UNSIGNED NOT NULL,
    `enabled`          TINYINT(1)   NOT NULL DEFAULT 1,
    `override_price`   INT          NULL,
    `override_deposit` INT          NULL,
    `stock_override`   INT          NULL,
    `sort_order`       INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_loc_veh` (`location_id`, `vehicle_id`),
    KEY `idx_location` (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rentals_contracts` (
    `id`            INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `contract_num`  VARCHAR(20)    NOT NULL,
    `identifier`    VARCHAR(60)    NOT NULL,
    `player_name`   VARCHAR(80)    NOT NULL DEFAULT '',
    `location_id`   INT UNSIGNED   NOT NULL,
    `vehicle_model` VARCHAR(60)    NOT NULL,
    `plate`         VARCHAR(12)    NOT NULL,
    `token`         VARCHAR(64)    NOT NULL,
    `start_ts`      BIGINT         NOT NULL,
    `end_ts`        BIGINT         NOT NULL,
    `price_total`   INT UNSIGNED   NOT NULL DEFAULT 0,
    `deposit`       INT UNSIGNED   NOT NULL DEFAULT 0,
    `insurance`     VARCHAR(20)    NOT NULL DEFAULT 'none',
    `fuel_policy`   VARCHAR(20)    NOT NULL DEFAULT 'full_to_full',
    `delivery`      TINYINT(1)     NOT NULL DEFAULT 0,
    `payment_method` VARCHAR(16)   NOT NULL DEFAULT 'bank',
    `status`        VARCHAR(20)    NOT NULL DEFAULT 'active',
    `vehicle_netid` INT            NULL,
    `created_at`    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_plate` (`plate`),
    UNIQUE KEY `uk_token` (`token`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rentals_history` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `contract_id`      INT UNSIGNED NOT NULL,
    `contract_num`     VARCHAR(20)  NOT NULL DEFAULT '',
    `identifier`       VARCHAR(60)  NOT NULL,
    `vehicle_model`    VARCHAR(60)  NOT NULL,
    `plate`            VARCHAR(12)  NOT NULL,
    `penalties_json`   JSON         NULL,
    `scan_json`        JSON         NULL,
    `total_penalties`  INT UNSIGNED NOT NULL DEFAULT 0,
    `refunded_deposit` INT UNSIGNED NOT NULL DEFAULT 0,
    `returned_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_contract` (`contract_id`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Véhicules par défaut
-- ============================================================

INSERT IGNORE INTO `rentals_vehicles` (`model`, `label`, `category`, `tags`, `price_per_day`, `deposit`, `seats`, `trunk`, `speed`, `handling`, `braking`, `image_url`) VALUES
('blista',       'Blista Compact',  'compact',     'eco,citadine',        300,   500,  2, 30, 45, 55, 50, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/blista.png'),
('prairie',      'Prairie',         'compact',     'eco,citadine',        350,   600,  2, 30, 50, 50, 45, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/prairie.png'),
('issi2',        'Issi',            'compact',     'eco,mini',            280,   450,  2, 20, 40, 60, 55, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/issi2.png'),
('brioso',       'Brioso 300',      'compact',     'eco,retro',           320,   550,  2, 25, 42, 58, 52, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/brioso.png'),
('sultan',       'Sultan',          'sedan',       'familial,polyvalent', 500,   800,  4, 50, 65, 60, 55, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/sultan.png'),
('schafter2',    'Schafter V12',    'sedan',       'luxe,business',       700,  1200,  4, 45, 75, 65, 60, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/schafter2.png'),
('fugitive',     'Fugitive',        'sedan',       'familial',            450,   700,  4, 50, 55, 55, 50, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/fugitive.png'),
('tailgater',    'Tailgater',       'sedan',       'business,confort',    550,   900,  4, 45, 60, 60, 55, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/tailgater.png'),
('baller2',      'Baller LE',       'suv',         'luxe,familial',       800,  1500,  4, 60, 55, 50, 48, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/baller2.png'),
('granger',      'Granger',         'suv',         'familial,offroad',    600,  1000,  8, 70, 50, 45, 45, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/granger.png'),
('huntley',      'Huntley S',       'suv',         'luxe,confort',        750,  1300,  4, 55, 55, 52, 50, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/huntley.png'),
('comet2',       'Comet',           'sport',       'sport,performance',  1200,  2500,  2, 20, 85, 75, 70, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/comet2.png'),
('elegy2',       'Elegy RH8',       'sport',       'sport,jdm',          1000,  2000,  2, 25, 80, 80, 72, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/elegy2.png'),
('carbonizzare', 'Carbonizzare',    'sport',       'sport,cabriolet',    1100,  2200,  2, 20, 82, 72, 68, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/carbonizzare.png'),
('jester',       'Jester',          'sport',       'sport,jdm',          1300,  2600,  2, 20, 84, 78, 75, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/jester.png'),
('turismor',     'Turismo R',       'super',       'supercar,prestige',  2500,  5000,  2, 10, 95, 85, 80, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/turismor.png'),
('t20',          'T20',             'super',       'supercar,prestige',  3000,  6000,  2, 10, 98, 88, 82, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/t20.png'),
('adder',        'Adder',           'super',       'supercar,hypercar',  3500,  7000,  2, 10, 96, 82, 78, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/adder.png'),
('entityxf',     'Entity XF',       'super',       'supercar,prestige',  2800,  5500,  2, 10, 94, 84, 80, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/entityxf.png'),
('bison',        'Bison',           'utilitaire',  'utilitaire,cargo',    400,   700,  2, 80, 40, 40, 42, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/bison.png'),
('rumpo',        'Rumpo',           'utilitaire',  'utilitaire,van',      450,   800,  4, 90, 35, 38, 40, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/rumpo.png'),
('youga',        'Youga',           'utilitaire',  'utilitaire,van',      420,   750,  4, 85, 38, 42, 42, 'https://cdn.jsdelivr.net/gh/MericcaN41/gta5carimages@main/images/youga.png');

-- ============================================================
-- Points de location par défaut
-- ============================================================

INSERT IGNORE INTO `rentals_locations` (`name`, `coords_json`, `spawnpoints_json`, `showroom_json`, `blip_sprite`, `blip_color`, `ped_model`) VALUES
('Location Aéroport',
 '{"x":-1037.35,"y":-2738.07,"z":20.17,"h":328.0}',
 '[{"x":-1031.97,"y":-2730.78,"z":20.17,"h":238.0},{"x":-1028.42,"y":-2727.26,"z":20.17,"h":238.0}]',
 '{"x":-1025.0,"y":-2724.0,"z":20.17,"h":238.0}',
 226, 3, 's_m_m_autoshop_02'),
('Location Centre-Ville',
 '{"x":-224.68,"y":-1158.99,"z":23.03,"h":3.0}',
 '[{"x":-230.17,"y":-1155.23,"z":23.03,"h":0.0},{"x":-234.58,"y":-1155.23,"z":23.03,"h":0.0}]',
 '{"x":-237.0,"y":-1155.0,"z":23.03,"h":0.0}',
 226, 2, 's_m_m_autoshop_02');
