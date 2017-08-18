/*Grabbing all of the active prospects assigned to Dev Officers*/
WITH Proposal_List as (
SELECT DISTINCT PP.PROPOSAL_ID
       , PP.PROSPECT_ID
       , PPL.SORT_NAME AS PROSPECT_NAME
       , ASGMT.Priority_Code
       , ASGMT.ASSIGNMENT_TYPE
       , S.ID_NUMBER AS RM_Number
       , S.SORT AS RM_Name
       , PP.PROPOSAL_TYPE
       , PP.ACTIVE_IND
       , PP.PROPOSAL_STATUS_CODE
       , PS.SHORT_DESC AS Proposal_Status_Desc
       , PP.STAGE_CODE AS Current_Stage
       , TPS.SHORT_DESC AS Current_Stage_Desc
       , PP.START_DATE
       , PP.STOP_DATE
       , CASE WHEN PP.STOP_DATE IS NULL THEN 'FY 17-18'
              WHEN PP.STOP_DATE BETWEEN TO_DATE('7/1/2017', 'MM/DD/YYYY') AND TO_DATE('6/30/2018', 'MM/DD/YYYY') THEN 'FY 16-17'
              WHEN PP.STOP_DATE BETWEEN TO_DATE('7/1/2016', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY') THEN 'FY 16-17'
              WHEN PP.STOP_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2016', 'MM/DD/YYYY') THEN 'FY 15-16'
                ELSE NULL END AS Fiscal_Year
       , PP.PROPOSAL_TITLE
       , PP.ORIGINAL_ASK_AMT
       , PP.ASK_AMT
       , PP.GRANTED_AMT
       , PP.INITIAL_CONTRIBUTION_DATE
       , PP.PLAN_GIFT_IND
       , PP.UNIT_CODE
       , PP.Expected_Date
       , PPL.high_ucdt_or_capacity
       , PPL.abs_high_capacity_ucdt_asks
FROM ADVANCE.PROPOSAL PP
       LEFT JOIN ADVANCE.TMS_PROPOSAL_STATUS PS ON PP.PROPOSAL_STATUS_CODE = PS.PROPOSAL_STATUS_CODE
       LEFT JOIN ADVANCE.PROSPECT_ENTITY PE ON PP.PROSPECT_ID = PE.PROSPECT_ID AND PE.PRIMARY_IND = 'Y'
       LEFT JOIN ADVANCE.UCDR_PROSPECT_POOL PPL ON PE.ID_NUMBER = PPL.ID_NUMBER
       LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
            ON PP.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
       LEFT JOIN ADVANCE.STAFF S
            ON ASGMT.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER  AND S.ACTIVE_IND = 'Y'
       LEFT JOIN ADVANCE.TMS_PROPOSAL_STAGE TPS ON PP.STAGE_CODE = TPS.STAGE_CODE
WHERE PP.PROPOSAL_TYPE like 'MG%'
        AND (PP.STOP_DATE >= TO_DATE('7/1/2015', 'MM/DD/YYYY')
/*        AND (PP.STOP_DATE BETWEEN (TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY'))*/
            OR PP.STOP_DATE IS NULL)
)

/*Duration for each stage of each proposal*/
, Stage_Time as (
SELECT  T.PROPOSAL_ID
        , T.STAGE_CODE
        , SUM(CASE WHEN T.NEXT_DATE IS NULL THEN (SYSDATE - T.STAGE_DATE)
               ELSE (T.NEXT_DATE - T.STAGE_DATE) END) AS DATEDIFF
FROM    (SELECT S1.PROPOSAL_ID 
                , S1.STAGE_CODE 
                , S1.STAGE_DATE 
                , (SELECT  MIN(STAGE_DATE) 
                   FROM     ADVANCE.STAGE S2
                   WHERE   S2.PROPOSAL_ID = S1.PROPOSAL_ID
                           AND     S2.STAGE_DATE > S1.STAGE_DATE
                  ) AS NEXT_DATE
          FROM ADVANCE.STAGE S1
          WHERE S1.PROPOSAL_ID IN (SELECT PROPOSAL_ID FROM PROPOSAL_LIST PPL)
        ) T
GROUP BY T.PROPOSAL_ID, T.STAGE_CODE
)

/*Most recent lead solicitator*/
, Lead_Solicitator as (
SELECT PROPOSAL_ID
       , ASSIGNMENT_ID_NUMBER
       , S.SORT
FROM (SELECT PL.PROPOSAL_ID
             , A.ASSIGNMENT_ID_NUMBER
             , ROW_NUMBER() OVER (PARTITION BY PL.PROPOSAL_ID ORDER BY A.START_DATE DESC) rn
     FROM Proposal_List PL
     LEFT JOIN ADVANCE.ASSIGNMENT A ON PL.PROPOSAL_ID = A.PROPOSAL_ID
     WHERE A.ASSIGNMENT_TYPE = 'SL' 
           AND A.PROPOSAL_ID IS NOT NULL
     ) LS
     LEFT JOIN ADVANCE.STAFF S ON LS.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER
WHERE rn = 1
)

SELECT PPL.PROPOSAL_ID
       , PPL.PROPOSAL_TYPE
       , PPL.PROPOSAL_TITLE
       , PPL.PROSPECT_ID
       , PPL.PROSPECT_NAME
       , LS.ASSIGNMENT_ID_NUMBER as "Lead Solicitator ID"
       , LS.SORT as "Lead Solicitator"
       , PPL.RM_Number as "RM Number if Active"
       , PPL.RM_Name as "RM Name if Active"
       , PPL.Priority_Code
       , PPL.ASSIGNMENT_TYPE
       , PPL.ACTIVE_IND as "Proposal Active Ind"
       , PPL.Proposal_Status_Desc
       , PPL.Current_Stage_Desc
       , PPL.START_DATE
       , PPL.STOP_DATE
       , PPL.Fiscal_Year
       , PPL.ORIGINAL_ASK_AMT
       , PPL.ASK_AMT
       , PPL.GRANTED_AMT
       , CASE WHEN PPL.ASK_AMT IS NULL OR PPL.ASK_AMT = 0 THEN 0
              ELSE PPL.GRANTED_AMT / PPL.ASK_AMT END as "Granted as % of Ask Amt"
       , PPL.high_ucdt_or_capacity
       , CASE WHEN PPL.high_ucdt_or_capacity IS NULL OR PPL.high_ucdt_or_capacity = 0 THEN 0
              ELSE PPL.ASK_AMT / PPL.high_ucdt_or_capacity END as "Ask as % of Capacity"
       , PPL.abs_high_capacity_ucdt_asks
       , CASE WHEN PPL.abs_high_capacity_ucdt_asks IS NULL OR PPL.abs_high_capacity_ucdt_asks = 0 THEN 0
              ELSE PPL.ASK_AMT / PPL.abs_high_capacity_ucdt_asks END as "Ask as % of Abs Capacity"
       , PPL.INITIAL_CONTRIBUTION_DATE as "Ask Date"
       , PPL.Expected_Date
       , PPL.PLAN_GIFT_IND
       , PPL.UNIT_CODE
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'RB') AS "Days at Ask Planned"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'AM') AS "Days at Ask Made"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'GC') AS "Days at Gift Closed"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'ST') AS "Days at Gift/Pledge Stwrdship"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'PL') AS "Days at PG Stewardship"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'DN') AS "Days at Declined"
       , (SELECT DATEDIFF FROM Stage_Time ST WHERE PPL.PROPOSAL_ID = ST.PROPOSAL_ID AND ST.STAGE_CODE = 'DP') AS "Days at Cancelled Solicitation"
       , SYSDATE as "Date Run"
FROM PROPOSAL_LIST PPL
       LEFT JOIN Lead_Solicitator LS ON PPL.PROPOSAL_ID = LS.PROPOSAL_ID
       
  
