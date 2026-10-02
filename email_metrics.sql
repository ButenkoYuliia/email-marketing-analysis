-- Email marketing metrics by date and country (Google BigQuery, DA dataset)
-- Combines account creation and email activity (sent / opened / visited),
-- adds country totals and ranks, keeps the top-10 countries by accounts or sent emails

WITH account_metrics AS (

    SELECT
        s.date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed,

        COUNT(DISTINCT a.id) AS account_cnt,
        0 AS sent_msg,
        0 AS open_msg,
        0 AS visit_msg

    FROM `data-analytics-mate.DA.account` a

    JOIN `data-analytics-mate.DA.account_session` ac
        ON a.id = ac.account_id

    JOIN `data-analytics-mate.DA.session` s
        ON ac.ga_session_id = s.ga_session_id

    JOIN `data-analytics-mate.DA.session_params` sp
        ON s.ga_session_id = sp.ga_session_id

    GROUP BY 1,2,3,4,5
),

sent_metrics AS (

    SELECT
        DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed,

        0 AS account_cnt,

        COUNT(DISTINCT es.id_message) AS sent_msg,
        COUNT(DISTINCT eo.id_message) AS open_msg,
        COUNT(DISTINCT ev.id_message) AS visit_msg

    FROM `data-analytics-mate.DA.email_sent` es

    JOIN `data-analytics-mate.DA.account` a
        ON es.id_account = a.id

    JOIN `data-analytics-mate.DA.account_session` ac
        ON a.id = ac.account_id

    JOIN `data-analytics-mate.DA.session` s
        ON ac.ga_session_id = s.ga_session_id

    JOIN `data-analytics-mate.DA.session_params` sp
        ON s.ga_session_id = sp.ga_session_id

    LEFT JOIN `data-analytics-mate.DA.email_open` eo
        ON es.id_message = eo.id_message
       AND es.id_account = eo.id_account

    LEFT JOIN `data-analytics-mate.DA.email_visit` ev
        ON es.id_message = ev.id_message
       AND es.id_account = ev.id_account

    GROUP BY 1,2,3,4,5
),

union_data AS (

    SELECT * FROM account_metrics

    UNION ALL

    SELECT * FROM sent_metrics
),

final_data AS (

    SELECT
        date,
        country,
        send_interval,
        is_verified,
        is_unsubscribed,

        SUM(account_cnt) AS account_cnt,
        SUM(sent_msg) AS sent_msg,
        SUM(open_msg) AS open_msg,
        SUM(visit_msg) AS visit_msg

    FROM union_data

    GROUP BY 1,2,3,4,5
),

country_totals AS (

    SELECT
        *,

        SUM(account_cnt) OVER (
            PARTITION BY country
        ) AS total_country_account_cnt,

        SUM(sent_msg) OVER (
            PARTITION BY country
        ) AS total_country_sent_cnt

    FROM final_data
),

ranked_data AS (

    SELECT
        *,

        DENSE_RANK() OVER (
            ORDER BY total_country_account_cnt DESC
        ) AS rank_total_country_account_cnt,

        DENSE_RANK() OVER (
            ORDER BY total_country_sent_cnt DESC
        ) AS rank_total_country_sent_cnt

    FROM country_totals
)

SELECT
    date,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,
    account_cnt,
    sent_msg,
    open_msg,
    visit_msg,
    total_country_account_cnt,
    total_country_sent_cnt,
    rank_total_country_account_cnt,
    rank_total_country_sent_cnt

FROM ranked_data

WHERE rank_total_country_account_cnt <= 10
   OR rank_total_country_sent_cnt <= 10

ORDER BY date;
