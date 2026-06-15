# Mapping Icons Material → Lucide

> But : remplacer les `Icons.xxx` Material par des SVG Lucide modernes via `DonyIcon`.
>
> **Nom Lucide = nom du fichier** à télécharger sur **lucide.dev** (bouton "Copy SVG"
> ou "Download SVG") et à poser dans `assets/icons/<nom>.svg`.
> URL directe : `https://lucide.dev/icons/<nom>`
>
> Usage ensuite : `DonyIcon('plane', color: DonyColors.primary)`.
>
> Colonne « # » = nombre d'occurrences dans le projet (priorité de migration).

---

## ⚠️ Règle camion (CLAUDE.md)

`Icons.local_shipping_rounded` (9) et `Icons.local_shipping_outlined` (3) → **NE PAS**
prendre l'icône camion Lucide `truck`. dony = transport voyageur (avion). Remplacer par
`package` (colis) ou `plane` selon le contexte.

---

## Navigation / flèches

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `chevron_right_rounded` | `chevron-right` | 34 |
| `chevron_left_rounded` | `chevron-left` | 8 |
| `arrow_forward_rounded` | `arrow-right` | 10 |
| `arrow_back_rounded` | `arrow-left` | 4 |
| `arrow_back_ios_rounded` / `arrow_back_ios_new_rounded` | `chevron-left` | 4 |
| `arrow_upward_rounded` | `arrow-up` | 1 |
| `arrow_downward_rounded` | `arrow-down` | 2 |
| `arrow_drop_down_rounded` / `keyboard_arrow_down_rounded` / `expand_more_rounded` | `chevron-down` | 3 |
| `open_in_full_rounded` | `maximize-2` | 2 |
| `open_in_new` / `open_in_browser_rounded` | `external-link` | 2 |

## Statuts / validation

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `check_rounded` / `check` / `done_rounded` | `check` | 38 |
| `check_circle_rounded` / `check_circle_outline_rounded` / `check_circle_outline` | `circle-check` | 41 |
| `done_all_rounded` | `check-check` | 1 |
| `close_rounded` / `close` / `clear_rounded` | `x` | 33 |
| `cancel_rounded` / `cancel_outlined` | `circle-x` | 12 |
| `error_outline_rounded` / `error_outline` / `error` | `circle-alert` | 40 |
| `warning_amber_rounded` / `warning_rounded` / `warning` | `triangle-alert` | 23 |
| `info_outline_rounded` | `info` | 18 |
| `block_rounded` / `block_outlined` / `do_not_disturb_alt_rounded` | `ban` | 15 |
| `verified_rounded` / `verified_outlined` / `verified` | `badge-check` | 22 |
| `verified_user_rounded` / `verified_user_outlined` | `shield-check` | 9 |
| `radio_button_unchecked_rounded` / `radio_button_unchecked` | `circle` | 5 |
| `radio_button_checked_rounded` / `adjust_rounded` | `circle-dot` | 4 |

## Voyage / transport (⚠️ pas de camion)

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `flight_takeoff_rounded` / `flight_takeoff` | `plane-takeoff` | 34 |
| `flight_land_rounded` | `plane-landing` | 16 |
| `flight_rounded` / `flight` / `flight_outlined` | `plane` | 15 |
| `luggage_rounded` / `luggage` | `luggage` | 6 |
| `commute_rounded` / `route_rounded` | `route` | 6 |
| `train_rounded` | `train-front` | 2 |
| `directions_car_rounded` | `car` | 2 |
| `directions_bus_rounded` | `bus` | 2 |
| `directions_boat_rounded` | `ship` | 2 |
| `near_me_rounded` / `near_me_outlined` | `navigation` | 2 |
| `my_location_rounded` / `location_searching_rounded` | `locate-fixed` | 4 |
| `local_shipping_rounded` / `local_shipping_outlined` | `package` ⚠️ | 12 |

## Colis / inventaire

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `inventory_2_rounded` / `inventory_2_outlined` | `package` | 25 |
| `inbox_rounded` / `inbox_outlined` / `move_to_inbox_rounded` | `inbox` | 11 |
| `archive_outlined` / `archive_rounded` | `archive` | 3 |
| `unarchive_outlined` | `archive-restore` | 1 |
| `folder_rounded` | `folder` | 1 |
| `checkroom_rounded` | `shirt` | 2 |

## Argent / paiement

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `payments_rounded` / `payments_outlined` / `payment_rounded` | `banknote` | 26 |
| `euro_rounded` / `euro_outlined` / `euro` | `euro` | 10 |
| `credit_card_rounded` / `credit_card_outlined` | `credit-card` | 10 |
| `credit_card_off_rounded` | `credit-card` | 1 |
| `account_balance_wallet_rounded` / `account_balance_wallet_outlined` | `wallet` | 5 |
| `account_balance_rounded` | `landmark` | 3 |
| `savings_rounded` | `piggy-bank` | 1 |
| `sell_rounded` / `sell_outlined` / `label_rounded` / `label_outline_rounded` | `tag` | 11 |
| `discount_outlined` | `badge-percent` | 1 |
| `receipt_long_rounded` | `receipt` | 1 |
| `card_giftcard_rounded` | `gift` | 3 |

## Localisation

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `location_on_rounded` / `location_on_outlined` / `place_rounded` / `place_outlined` / `pin_drop_rounded` | `map-pin` | 30 |
| `location_off_rounded` / `location_off_outlined` / `gps_off` | `map-pin-off` | 4 |
| `location_city_rounded` / `location_city_outlined` / `business_rounded` | `building-2` | 5 |
| `map_outlined` | `map` | 1 |
| `public_rounded` | `globe` | 2 |
| `home_rounded` / `home_outlined` / `house_rounded` | `house` | 7 |

## Temps / calendrier

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `schedule_rounded` / `schedule_outlined` / `access_time_rounded` | `clock` | 26 |
| `calendar_today_rounded` / `calendar_today_outlined` / `calendar_month_rounded` / `event_rounded` | `calendar` | 20 |
| `event_repeat_rounded` | `calendar-sync` | 2 |
| `event_busy_rounded` | `calendar-x` | 2 |
| `hourglass_top_rounded` / `hourglass_empty_rounded` / `hourglass_disabled_rounded` | `hourglass` | 16 |
| `timer_rounded` / `timer_outlined` | `timer` | 6 |
| `timer_off_rounded` / `timer_off_outlined` | `timer-off` | 5 |
| `history_rounded` | `history` | 1 |
| `pending_rounded` / `pending_actions_rounded` | `clock-alert` | 2 |
| `lock_clock_rounded` | `clock` | 2 |

## Verrou / sécurité

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `lock_rounded` / `lock_outline_rounded` / `lock_outlined` / `lock_outline` / `lock` | `lock` | 36 |
| `lock_open_rounded` / `lock_open_outlined` | `lock-open` | 2 |
| `lock_reset_rounded` | `lock-keyhole` | 1 |
| `vpn_key_rounded` / `password_rounded` / `pin_rounded` | `key-round` | 5 |
| `fingerprint_rounded` / `fingerprint` | `fingerprint` | 2 |
| `shield_rounded` / `shield_outlined` | `shield` | 7 |
| `security_rounded` | `shield-check` | 2 |
| `gpp_bad_rounded` | `shield-x` | 1 |
| `gavel_rounded` | `gavel` | 2 |
| `balance_rounded` | `scale` | 1 |
| `policy_outlined` | `file-badge` | 1 |

## Communication / notifications

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `chat_bubble_outline_rounded` / `chat_bubble_rounded` / `message_rounded` | `message-circle` | 16 |
| `forum_rounded` | `messages-square` | 1 |
| `send_rounded` / `send` | `send` | 7 |
| `phone_rounded` / `phone_outlined` | `phone` | 12 |
| `phone_android_rounded` / `phone_android_outlined` / `smartphone_rounded` / `devices_rounded` | `smartphone` | 8 |
| `email_outlined` / `email_rounded` | `mail` | 8 |
| `alternate_email_rounded` | `at-sign` | 1 |
| `mark_email_unread_outlined` | `mail-warning` | 1 |
| `notifications_active_rounded` / `notifications_rounded` / `notifications_outlined` / `notifications_none_rounded` | `bell` | 13 |
| `notifications_off_rounded` / `notifications_off_outlined` | `bell-off` | 6 |
| `support_agent_rounded` / `headset_mic_rounded` | `headset` | 2 |
| `headphones_rounded` | `headphones` | 1 |
| `contacts_rounded` | `contact` | 1 |

## Personne / compte

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `person_rounded` / `person_outline_rounded` | `user` | 10 |
| `person_off_rounded` | `user-x` | 3 |
| `person_search_rounded` | `user-search` | 1 |
| `group_add_rounded` | `user-plus` | 1 |
| `manage_accounts_rounded` | `user-cog` | 1 |
| `badge_rounded` | `id-card` | 1 |
| `face_outlined` / `face_retouching_natural_rounded` | `scan-face` | 2 |
| `accessibility_new_rounded` | `accessibility` | 1 |
| `handshake_rounded` / `handshake_outlined` | `handshake` | 3 |

## Actions / édition

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `add_rounded` / `add` | `plus` | 18 |
| `add_box_outlined` | `square-plus` | 2 |
| `add_a_photo_outlined` | `image-plus` | 1 |
| `remove_rounded` / `remove` | `minus` | 3 |
| `edit_rounded` / `edit_outlined` | `square-pen` | 11 |
| `edit_note_rounded` | `notebook-pen` | 3 |
| `edit_location_alt_outlined` | `map-pin-pen` | 1 |
| `delete_outline_rounded` / `delete_rounded` | `trash-2` | 27 |
| `delete_forever_rounded` | `trash` | 2 |
| `copy_rounded` | `copy` | 6 |
| `share_rounded` / `ios_share_rounded` | `share-2` | 8 |
| `download_rounded` | `download` | 4 |
| `upload_rounded` | `upload` | 2 |
| `refresh_rounded` / `sync_rounded` / `replay_rounded` | `refresh-cw` | 16 |
| `sync_alt_rounded` / `swap_horiz_rounded` | `arrow-left-right` | 12 |
| `search_rounded` | `search` | 13 |
| `search_off_rounded` | `search-x` | 5 |
| `tune_rounded` | `sliders-horizontal` | 6 |
| `filter_list_rounded` | `list-filter` | 1 |
| `filter_alt_off_rounded` | `filter-x` | 1 |
| `more_vert_rounded` | `ellipsis-vertical` | 7 |
| `more_horiz_rounded` | `ellipsis` | 6 |
| `link_rounded` | `link` | 1 |

## QR / scan / photo

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `qr_code_scanner_rounded` | `scan-line` | 10 |
| `qr_code_rounded` / `qr_code_2_rounded` / `qr_code_2_outlined` | `qr-code` | 9 |
| `camera_alt_rounded` / `camera_alt_outlined` / `photo_camera_rounded` | `camera` | 9 |
| `photo_library_outlined` / `image_rounded` / `image_outlined` | `image` | 3 |
| `broken_image_rounded` / `broken_image_outlined` | `image-off` | 3 |
| `dialpad_rounded` | `grid-3x3` | 2 |
| `backspace_outlined` | `delete` | 1 |

## Divers

| Material | Lucide (fichier) | # |
|----------|------------------|---|
| `star_rounded` / `stars_rounded` / `star_outline_rounded` / `star_border_rounded` | `star` | 50 |
| `bookmark_rounded` / `bookmark_border_rounded` | `bookmark` | 9 |
| `bolt_rounded` / `bolt_outlined` / `flash_on_rounded` | `zap` | 9 |
| `speed_rounded` | `gauge` | 2 |
| `scale_rounded` / `scale_outlined` / `monitor_weight_outlined` | `scale` | 14 |
| `fitness_center_rounded` | `dumbbell` | 2 |
| `waves_rounded` | `waves` | 5 |
| `wifi_off_rounded` / `signal_wifi_off_rounded` / `cloud_off_rounded` | `wifi-off` | 25 |
| `wifi_rounded` | `wifi` | 1 |
| `signal_cellular_alt_rounded` | `signal` | 1 |
| `auto_awesome_rounded` | `sparkles` | 2 |
| `rocket_launch_rounded` | `rocket` | 1 |
| `workspace_premium_rounded` / `workspace_premium_outlined` | `award` | 3 |
| `trending_up_rounded` | `trending-up` | 1 |
| `timeline_rounded` | `chart-line` | 1 |
| `track_changes_rounded` | `target` | 1 |
| `all_inclusive_rounded` | `infinity` | 2 |
| `tag_rounded` | `tag` | 2 |
| `description_rounded` / `article_outlined` / `notes_rounded` / `notes` | `file-text` | 6 |
| `assignment_turned_in_rounded` | `clipboard-check` | 1 |
| `rule_rounded` | `list-checks` | 2 |
| `quiz_rounded` | `circle-help` | 1 |
| `bug_report_outlined` | `bug` | 3 |
| `lightbulb_rounded` / `lightbulb_outline_rounded` | `lightbulb` | 2 |
| `light_mode_rounded` / `light_mode_outlined` | `sun` | 2 |
| `dark_mode_rounded` / `dark_mode_outlined` | `moon` | 2 |
| `brightness_auto_rounded` / `brightness_auto_outlined` | `sun-moon` | 2 |
| `contrast_rounded` | `contrast` | 1 |
| `translate_rounded` | `languages` | 2 |
| `grid_view_rounded` / `grid_view_outlined` | `layout-grid` | 2 |
| `sd_storage_outlined` | `sd-card` | 1 |
| `kitchen_rounded` | `refrigerator` | 1 |
| `weekend_rounded` | `sofa` | 1 |
| `spa_rounded` | `flower` | 1 |
| `medication_rounded` / `medical_services_rounded` | `pill` | 2 |
| `bakery_dining_rounded` | `croissant` | 1 |
| `speaker_rounded` | `speaker` | 1 |
| `animation_rounded` / `play_circle_outline_rounded` | `circle-play` | 2 |
| `cake_outlined` | `cake` | 1 |
| `meeting_room_outlined` | `door-open` | 1 |
| `flag_outlined` | `flag` | 2 |
| `visibility_outlined` | `eye` | 2 |
| `visibility_off_rounded` | `eye-off` | 1 |
| `apple` | `apple` | 1 |

---

## Custom — déjà non-Material, ignorer

Ces `Icons.xxx` ne sont **pas** Material (set custom du projet ou faux positif grep) :
`back`, `chevron`, `arrowRight`, `mapPin`, `suitcase`, `departureCity`, `arrivalCity`,
`time`, `date`, `minus`, `send` (selon contexte), `containsKey` (faux positif — appel `.containsKey()`).

---

## Workflow de migration

1. Choisis un écran (commence par le plus visible).
2. Pour chaque `Icons.xxx` → trouve la ligne dans ce mapping → note le nom Lucide.
3. Va sur `https://lucide.dev/icons/<nom>` → "Copy SVG".
4. Crée `assets/icons/<nom>.svg`, colle.
5. Remplace `Icon(Icons.xxx, ...)` → `DonyIcon('<nom>', color: ..., size: ...)`.
6. **Full restart** (nouveaux assets non vus par hot reload).

### Astuce — tout télécharger d'un coup

Tous les SVG Lucide sont sur GitHub (`lucide-icons/lucide/icons/<nom>.svg`). Ex CDN unitaire :
`https://unpkg.com/lucide-static@latest/icons/<nom>.svg`

Script pour récupérer une liste de noms d'un coup (à lancer dans `assets/icons/`) :
```bash
for name in plane plane-takeoff plane-landing package wallet star map-pin clock; do
  curl -sL "https://unpkg.com/lucide-static@latest/icons/$name.svg" -o "$name.svg"
done
```
