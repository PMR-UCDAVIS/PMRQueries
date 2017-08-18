/*Grabbing all of the active prospects assigned to Dev Officers*/
WITH Prospect_List as (
Select DISTINCT P.Prospect_Id
       , S.ID_NUMBER AS RM_Number
       , S.SORT AS RM_Name
       , P.STAGE_CODE
       , TMS_S.SHORT_DESC
       , ASGMT.Priority_Code
       , ASGMT.ASSIGNMENT_TYPE
from ADVANCE.PROSPECT P
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON P.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
     INNER JOIN ADVANCE.STAFF S
           ON ASGMT.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER 
     LEFT OUTER JOIN ADVANCE.Tms_Stage TMS_S
          ON P.STAGE_CODE = TMS_S.STAGE_CODE
WHERE P.ACTIVE_IND = 'Y' 
/*      and S.ID_NUMBER NOT IN (
          '0000886412'
          , '0000934169'
          , '0000703749'
          , '0000914804'
          , '0000667353'
          , '0000761072'
          , '0000629408'
          , '0000710242'
          , '0001018506' )*/
      and S.ACTIVE_IND = 'Y'
      and S.STAFF_TYPE_CODE = 'DEV'
/*      and s.unit_code NOT IN ( 'ASGP')*/
)

/*Grabbing portfolio sizes and total PQ prospects for each RM*/
, DO_Portfolio as (
Select  P.RM_Number
        , P.RM_Name
        , COUNT(P.PROSPECT_ID) Portfolio_Size
        , (SELECT COUNT(PROSPECT_ID) FROM Prospect_List PpL WHERE Priority_Code = 'PQ' AND PpL.RM_Number = P.RM_Number) PQ_Size
        , (SELECT COUNT(PROSPECT_ID) FROM Prospect_List PpL WHERE Priority_Code = 'PM' AND PpL.RM_Number = P.RM_Number) PM_Size
        , O.SHORT_DESC AS Office
        , U.SHORT_DESC AS Unit
        , (SYSDATE - CASE WHEN S.START_DATE IS NULL THEN S.DATE_ADDED ELSE S.START_DATE END) / 365 Time_as_DO
        , CASE WHEN U.SHORT_DESC = 'Planned Giving' THEN 'Planned Giving Officer'
            WHEN U.SHORT_DESC = 'Principal Gifts' THEN 'Principal Gifts Officer'
            WHEN U.SHORT_DESC = 'Foundation & Corporate Giving' THEN 'Foundation and Corporate Officer'
            WHEN U.SHORT_DESC = 'Annual & Special Gifts' OR P.RM_Number in ('0000629408', '0000761072') THEN 'Annual Special'
            WHEN P.RM_Number in ('0001058283', '0000886412', '0000667353', '0000934169', '0001018506', '0000914804', '0001058284') THEN 'Leadership'
              ELSE 'Major Gift Officer' END AS DO_Type
from Prospect_List P
     LEFT OUTER JOIN ADVANCE.STAFF S ON P.RM_Number = S.ID_NUMBER
     LEFT OUTER JOIN ADVANCE.TMS_OFFICE O ON S.OFFICE_CODE = O.OFFICE_CODE
     LEFT OUTER JOIN ADVANCE.TMS_UNIT_CODE U ON S.Unit_Code = U.UNIT_CODE
GROUP BY P.RM_Number, P.RM_Name, O.SHORT_DESC, U.SHORT_DESC , (SYSDATE - CASE WHEN S.START_DATE IS NULL THEN S.DATE_ADDED ELSE S.START_DATE END) / 365
)

/*Team Member size*/
, DO_Team as (
SELECT ASSIGNMENT_ID_NUMBER
       , COUNT(Prospect_Id) AS Team_Member_Size
FROM (
        Select DISTINCT P.Prospect_Id
               , ASGMT.ASSIGNMENT_ID_NUMBER
        from ADVANCE.PROSPECT P
             LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
                  ON P.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'S'
             INNER JOIN ADVANCE.STAFF S
                  ON ASGMT.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER 
        WHERE P.ACTIVE_IND = 'Y' 
              and S.ACTIVE_IND = 'Y'
              and S.STAFF_TYPE_CODE = 'DEV'
      )
GROUP BY ASSIGNMENT_ID_NUMBER
)

/*Calculating all contacts (visits, asks) and strategies for prospects in RM portfolio*/
, Contacts_RM as (
Select Prosp.Prospect_Id
       , CR.Author_ID_NUMBER
       , COUNT(CASE WHEN CR.CONTACT_TYPE in ('C', 'V', 'P', '1') THEN 1 ELSE NULL END) AS Total_RM_Contacts
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Total_RM_Visit
       , COUNT(CASE WHEN CR.Contact_Purpose_Code in ('A', 'B') AND CR.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_RM_Ask_or_Special
       , COUNT(CASE WHEN CR.Contact_Purpose_Code in ('A') AND CR.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_RM_Ask
       , COUNT(CASE WHEN CR.Contact_Purpose_Code in ('B') AND CR.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_RM_Special
       , COUNT(CASE WHEN CR.Contact_Type = 'S' THEN 1 ELSE NULL END) AS Strategy
       , COUNT(CASE WHEN CR.Contact_Outcome in ('DD', 'NN', 'NR') THEN 1 ELSE NULL END) AS DQ_NN_NR
       , COUNT(CASE WHEN CR.Contact_Outcome = 'QU' THEN 1 ELSE NULL END) AS QU_Contacts
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating all any DO contacts (visits, asks) for prospects in RM portfolio*/
, Contacts_Any_DO as (
Select Prosp.Prospect_Id
/*       , CR2.Author_ID_NUMBER*/
       , COUNT(CASE WHEN CR2.CONTACT_TYPE in ('C', 'V', 'P', '1') THEN 1 ELSE NULL END) AS Total_Any_DO_Contacts
       , COUNT(CASE WHEN CR2.CONTACT_TYPE = 'V' THEN CR2.CONTACT_DATE 
                  WHEN (CR2.CONTACT_TYPE in ('C', 'P') and CR2.Contact_Initiated_By = 'FCGS') THEN CR2.CONTACT_DATE 
                    ELSE NULL END) Total_Any_DO_Visit
       , COUNT(CASE WHEN CR2.Contact_Purpose_Code in ('A', 'B') AND CR2.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_Any_DO_Ask_or_Special
       , COUNT(CASE WHEN CR2.Contact_Purpose_Code in ('A') AND CR2.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_Any_DO_Ask
       , COUNT(CASE WHEN CR2.Contact_Purpose_Code in ('B') AND CR2.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_Any_DO_Special
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR2
          ON Prosp.Prospect_Id = CR2.Prospect_Id
          AND CR2.CONTACT_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
GROUP BY Prosp.Prospect_Id/*, CR2.Author_ID_NUMBER*/
)

/*Calculating all contacts (visits, asks) and strategies for prospects in RM PQ portfolio*/
, Contacts_RM_PQ as (
Select Prosp.Prospect_Id
       , CR.Author_ID_NUMBER
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Total_RM_Visit
       , COUNT(CASE WHEN CR.Contact_Purpose_Code in ('A') AND CR.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_RM_Ask
       , COUNT(CASE WHEN CR.Contact_Type = 'S' THEN 1 ELSE NULL END) AS Strategy
       , COUNT(CASE WHEN CR.CONTACT_OUTCOME <> ' ' THEN 1 ELSE NULL END) AS Qualified
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
WHERE Prosp.Priority_Code = 'PQ'
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating all contacts (visits, asks) and strategies for prospects in RM PQ portfolio*/
, Contacts_RM_PM as (
Select Prosp.Prospect_Id
       , CR.Author_ID_NUMBER
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Total_RM_Visit
       , COUNT(CASE WHEN CR.Contact_Purpose_Code in ('A') AND CR.CONTACT_TYPE in ('V', 'C', 'P') THEN 1 
         ELSE NULL END) AS Total_RM_Ask
       , COUNT(CASE WHEN CR.Contact_Type = 'S' THEN 1 ELSE NULL END) AS Strategy
       , COUNT(CASE WHEN CR.CONTACT_OUTCOME <> ' ' THEN 1 ELSE NULL END) AS Qualified
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
WHERE Prosp.Priority_Code = 'PM'
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating giving for all prospects in date range 7/1/2015 - 6/30/2017*/
, Giving as (
SELECT Prosp.Prospect_Id
       , SUM(G.PRIM_AMT) AS Total_Giving
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL POOL 
          ON PROSP.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
     LEFT OUTER JOIN ADVANCE.UCDR_GIVING G
          ON Pool.Id_Number = G.ID_NUMBER AND G.DATE_OF_RECORD BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
WHERE G.DATE_OF_RECORD BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
GROUP BY Prosp.Prospect_Id
)

/*All AssignemntREPORT_IDDO*/
, All_Assignemnts as (
SELECT DISTINCT A.ASSIGNMENT_ID_NUMBER AS RM_Number
       , A.PROSPECT_ID
       , PE.ID_NUMBER
FROM ADVANCE.ASSIGNMENT A
     LEFT JOIN ADVANCE.PROSPECT_ENTITY PE ON A.PROSPECT_ID = PE.PROSPECT_ID /*AND PE.PRIMARY_IND = 'Y'*/
WHERE A.ASSIGNMENT_ID_NUMBER in (SELECT DISTINCT P.RM_NUMBER FROM PROSPECT_LIST P)
      AND A.ACTIVE_IND = 'Y'
      AND A.PROPOSAL_ID IS NULL
      AND A.ASSIGNMENT_TYPE in ('S', 'LM')
)

/*Visits outside of RM portfolio*/
, Visits_Outside_Portfolio as (
select CR.Author_Id_Number AS RM_Number
       , CR.ID_NUMBER
       , COUNT(CR.REPORT_ID) AS Num_Visit_Outside
FROM ADVANCE.CONTACT_REPORT CR
     LEFT JOIN All_Assignemnts AA ON CR.AUTHOR_ID_NUMBER = AA.RM_Number AND CR.ID_NUMBER = AA.ID_NUMBER
WHERE AA.RM_Number IS NULL
      AND (CR.CONTACT_TYPE = 'V' OR (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS'))
      AND CR.CONTACT_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
      AND CR.AUTHOR_ID_NUMBER in (SELECT DISTINCT PL.RM_NUMBER FROM PROSPECT_LIST PL)
GROUP BY CR.AUTHOR_ID_NUMBER, CR.ID_NUMBER
)

/*Proposal Stats*/
, Proposals as (
SELECT PL.PROSPECT_ID
       , COUNT(PP.PROPOSAL_ID) AS Num_Proposals
       , COUNT(CASE WHEN PP.Stage_Code in ('AM', 'DN', 'GC', 'PL', 'ST') THEN 1 ELSE NULL END) AS Ask_Made
       , (SELECT COUNT(PP.PROPOSAL_ID) FROM ADVANCE.PROPOSAL PP
            WHERE PP.PROSPECT_ID = PL.PROSPECT_ID
                  AND PP.START_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
                  AND PP.PROPOSAL_TYPE like 'MG%' 
                  AND PP.PROPOSAL_ID NOT IN (Select P.PROPOSAL_ID 
                     FROM ADVANCE.PROPOSAL P
                     LEFT JOIN ADVANCE.STAGE S ON P.PROPOSAL_ID = S.PROPOSAL_ID 
                     WHERE P.DATE_ADDED BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
                     AND  S.STAGE_CODE in ('AM', 'GC', 'DN', 'ST'))
                  AND PP.PROPOSAL_ID IN (Select P.PROPOSAL_ID 
                     FROM ADVANCE.PROPOSAL P
                     LEFT JOIN ADVANCE.STAGE S ON P.PROPOSAL_ID = S.PROPOSAL_ID 
                     WHERE P.DATE_ADDED BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
                     AND  S.STAGE_CODE = 'DP')) AS Dropped_Before_AM
        , COUNT(CASE WHEN PP.Stage_Code in ('GC', 'PL', 'ST') THEN 1 ELSE NULL END) AS Closed
FROM Prospect_List PL
     LEFT JOIN ADVANCE.PROPOSAL PP ON PP.PROSPECT_ID = PL.PROSPECT_ID
WHERE PP.START_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
      AND PROPOSAL_TYPE like 'MG%'
GROUP BY PL.PROSPECT_ID
)

,  Time_At_Stage_Proposals as (
SELECT Prospect_ID
       , STAGE_DATE
       , STAGE_CODE
       , (SYSDATE - STAGE_DATE) / 365 Time_at_Stage
       , RM_Number
       , PROPOSAL_ID
FROM (
  SELECT P.PROSPECT_ID
         , S.STAGE_DATE
         , ROW_NUMBER() OVER (PARTITION BY P.Prospect_Id, PP.PROPOSAL_ID ORDER BY S.DATE_ADDED DESC) rn
         , PP.STAGE_CODE
         , P.RM_Number
         , PP.PROPOSAL_ID
  FROM Prospect_List P
       LEFT JOIN ADVANCE.PROPOSAL PP ON P.PROSPECT_ID = PP.PROSPECT_ID AND PP.PROPOSAL_TYPE like 'MG%'
       LEFT JOIN ADVANCE.STAGE S ON P.PROSPECT_ID = S.Prospect_ID AND PP.STAGE_CODE = S.STAGE_CODE AND PP.PROPOSAL_ID = S.PROPOSAL_ID
  WHERE PP.PROPOSAL_ID IS NOT NULL
      )
WHERE rn = 1
)

, Time_At_Stage as (
SELECT Prospect_ID
       , STAGE_DATE
       , STAGE_CODE
       , (SYSDATE - STAGE_DATE) / 365 Time_at_Stage
       , RM_Number
FROM (
  SELECT P.PROSPECT_ID
         , S.STAGE_DATE
         , ROW_NUMBER() OVER (PARTITION BY P.Prospect_Id ORDER BY S.DATE_ADDED DESC) rn
         , P.STAGE_CODE
         , P.RM_Number
  FROM Prospect_List P
       LEFT JOIN ADVANCE.STAGE S ON P.PROSPECT_ID = S.Prospect_ID AND P.STAGE_CODE = S.STAGE_CODE
      )
WHERE rn = 1
)

select Prosp.RM_Name AS "RM Name"
       , Prosp.RM_Number AS "RM Number"
       , DOP.Office
       , DOP.Unit
       , DOP.DO_Type AS "DO Type"
       , DOP.Time_as_DO as "Years as DO"
       , DOP.Portfolio_Size AS "Portfolio Size"
       , DT.Team_Member_Size AS "Count as Team Member"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE in ('ST', 'CU', 'SO') AND Prosp.RM_Number = PR.RM_Number) AS "Total Qualified"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'Q' AND Prosp.RM_Number = PR.RM_Number) AS "Total to be Qualified"
       , COUNT(CASE WHEN CRM.Total_RM_Ask > 0 THEN 1 ELSE NULL END) AS "Total Ask Made (Major) by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Ask > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made (Major) by RM"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Ask > 0 THEN 1 ELSE NULL END) AS "Total Ask Made (Major) Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Ask > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made (Major) by Any DO"
       , COUNT(CASE WHEN CRM.Total_RM_Ask_or_Special > 0 THEN 1 ELSE NULL END) AS "Total Ask Made (MG/A+S) by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Ask_or_Special > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made (MG/A+S) by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Special > 0 THEN 1 ELSE NULL END) AS "Total Ask Made Special by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Special > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made Special by RM"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Ask_or_Special > 0 THEN 1 ELSE NULL END) AS "Total Ask Made (MG/A+S) Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Ask_or_Special > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made (MG/A+S) by Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Special > 0 THEN 1 ELSE NULL END) AS "Total Ask Made Special Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Special > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Ask Made Special by Any DO"
       , COUNT(CASE WHEN CRM.Total_RM_Contacts > 0 THEN 1 ELSE NULL END) as "Total Contacted by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Contacts > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size as "% Contacted by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) AS "Total Visited by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Visited by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Visit > 1 THEN 1 ELSE NULL END) AS "Total Visited 2+ by RM"
       , COUNT(CASE WHEN CRM.Total_RM_Visit > 1 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Visited 2+ by RM"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Contacts > 0 THEN 1 ELSE NULL END) AS "Total Contacted by Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Contacts > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size  AS "% Contacted by Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Visit > 0 THEN 1 ELSE NULL END) AS "Total Visited by Any DO"
       , COUNT(CASE WHEN CAD.Total_Any_DO_Visit > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Visited by Any DO"
       , (SELECT COUNT(VOP.RM_Number) FROM Visits_Outside_Portfolio VOP WHERE Prosp.RM_Number = VOP.RM_Number ) AS "Visits Outside Portfolio"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 50000 THEN 1 ELSE NULL END) AS "Total Rated < $50k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 50000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated < $50k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 THEN 1 ELSE NULL END) AS "Total Rated >= $50k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated >= $50k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 100000 THEN 1 ELSE NULL END) AS "Total Rated < $100k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 100000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated < $100k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 100000 THEN 1 ELSE NULL END) AS "Total Rated >= $100k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 100000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated >= $100k"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 1000000 THEN 1 ELSE NULL END) AS "Total Rated < $1M"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 1000000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated < $1M"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 1000000 THEN 1 ELSE NULL END) AS "Total Rated >= $1M"
       , COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 1000000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Rated >= $1M"
       , COUNT(CASE WHEN GV.Total_Giving = 0 THEN NULL 
                    WHEN GV.Total_Giving IS NULL THEN NULL ELSE 1 END)AS "Total Gave During Timeframe"
       , COUNT(CASE WHEN GV.Total_Giving = 0 THEN NULL 
                    WHEN GV.Total_Giving IS NULL THEN NULL ELSE 1 END) / DOP.Portfolio_Size AS "% Gave During Timeframe"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'Q' AND Prosp.RM_Number = PR.RM_Number) AS "Total at Qualification"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'Q' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at Qualification"
       , (SELECT COUNT(TS.PROSPECT_ID) FROM Time_At_Stage TS WHERE TS.STAGE_CODE = 'Q' AND TS.Time_at_Stage >= 1 AND TS.RM_Number = Prosp.RM_Number) / DOP.Portfolio_Size AS "% at Qualification for 1+ yr"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'CU' AND Prosp.RM_Number = PR.RM_Number) AS "Total at Cultivation"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'CU' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at Cultivation"
       , (SELECT COUNT(TS.PROSPECT_ID) FROM Time_At_Stage TS WHERE TS.STAGE_CODE = 'CU' AND TS.Time_at_Stage >= 1 AND TS.RM_Number = Prosp.RM_Number) / DOP.Portfolio_Size AS "% at Cultivation for 1+ yr"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'SO' AND Prosp.RM_Number = PR.RM_Number) AS "Total at Active Solicitation"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'SO' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at Active Solicitation"
       , (SELECT COUNT(TS.PROSPECT_ID) FROM Time_At_Stage TS WHERE TS.STAGE_CODE = 'SO' AND TS.Time_at_Stage >= 1 AND TS.RM_Number = Prosp.RM_Number) / DOP.Portfolio_Size AS "% at Active Solic for 1+ yr"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'ST' AND Prosp.RM_Number = PR.RM_Number) AS "Total at Stewardship"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'ST' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at Stewardship"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'PL' AND Prosp.RM_Number = PR.RM_Number) AS "Total at PG Stewardship"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'PL' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at PG Stewardship"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'PS' AND Prosp.RM_Number = PR.RM_Number) AS "Total at Permanent Stewardship"
       , (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'PS' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size AS "% at Permanent Stewardship"
       , COUNT(CASE WHEN CRM.Strategy > 0 THEN 1 ELSE NULL END) AS "Total Documented Strategy"
       , COUNT(CASE WHEN CRM.Strategy > 0 THEN 1 ELSE NULL END) / DOP.Portfolio_Size AS "% Documented Strategy"
       , COUNT(CASE WHEN CRM.DQ_NN_NR > 0 THEN 1 ELSE NULL END) AS "Total DQ NN NR"
       , COUNT(CASE WHEN CRM.QU_Contacts > 0 THEN 1 ELSE NULL END) AS "Total Prospects Qualified (CR)"
       , SUM(PP.Num_Proposals) As "Total Proposals"
       , SUM(PP.Ask_Made) AS "Total Ask Made Proposals"
       , SUM(PP.Ask_Made) / SUM(PP.Num_Proposals) AS "% Ask Made Proposals"
       , SUM(PP.Dropped_Before_AM) AS "Total Dropped Before Ask Made"
       , SUM(PP.Dropped_Before_AM) / SUM(PP.Num_Proposals) AS "% Dropped Before Ask Made"
       , SUM(PP.Closed) AS "Total Proposals Closed"
       , SUM(PP.Closed) / SUM(PP.Num_Proposals) AS "% Proposals Closed"
       , (SELECT COUNT(TASP.PROSPECT_ID) FROM Time_At_Stage_Proposals TASP WHERE TASP.RM_NUMBER = Prosp.RM_Number AND TASP.Time_at_Stage >= 1 AND TASP.STAGE_CODE = 'RB') / SUM(PP.Num_Proposals) AS "% at Ask Planned 1+ yr"
       , (SELECT COUNT(TASP.PROSPECT_ID) FROM Time_At_Stage_Proposals TASP WHERE TASP.RM_NUMBER = Prosp.RM_Number AND TASP.Time_at_Stage >= 1 AND TASP.STAGE_CODE = 'AM') / SUM(PP.Num_Proposals) AS "% at Ask Made 1+ yr"
       , TRUNC(DOP.Time_as_DO) as "Years as DO Rounded Down"
       , CASE WHEN DOP.DO_Type = 'Planned Giving Officer' AND DOP.Portfolio_Size >= 75 THEN 'Yes'
              WHEN DOP.DO_Type = 'Principal Gifts Officer' AND DOP.Portfolio_Size >= 30 THEN 'Yes'
              WHEN DOP.DO_Type = 'Foundation and Corporate Officer' AND DOP.Portfolio_Size >= 30 THEN 'Yes'
              WHEN DOP.DO_Type = 'Annual Special' AND DOP.Portfolio_Size >= 200 THEN 'Yes'
              WHEN DOP.DO_Type = 'Leadership' THEN 'N/A'
                ELSE 'No' END AS "Recommended Portfolio Size?"
       , CASE WHEN COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks >= 100000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size > .5 THEN 'Yes'
              ELSE 'No' END AS "Portfolio rated $100k+"
       , CASE WHEN COUNT(CASE WHEN POOL.Abs_High_Capacity_Ucdt_Asks < 50000 THEN 1 ELSE NULL END) / DOP.Portfolio_Size > .25 THEN 'Yes'
              ELSE 'No' END AS "Portfolio rated < $50k"
       , CASE WHEN (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'Q' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size > .25 THEN 'Yes'
              ELSE 'No' END AS "Qualification > 25%"
       , CASE WHEN ((SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'CU' AND Prosp.RM_Number = PR.RM_Number) 
              + (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'ST' AND Prosp.RM_Number = PR.RM_Number)) / DOP.Portfolio_Size >= .5 THEN 'Yes'
              ELSE 'No' END AS "Cultivation/Stewardship > 50%" 
       , CASE WHEN (SELECT COUNT(Pr.PROSPECT_ID) FROM Prospect_List Pr WHERE PR.STAGE_CODE = 'SO' AND Prosp.RM_Number = PR.RM_Number) / DOP.Portfolio_Size >= .1 THEN 'Yes'
              ELSE 'No' END AS "Active Solicitation > 10%"
       , CASE WHEN COUNT(CASE WHEN CRM.Total_RM_Contacts = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .25 THEN '<25%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Contacts = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .50 THEN '25%-50%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Contacts = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Contact by RM Quartile"
       , CASE WHEN COUNT(CASE WHEN CRM.Total_RM_Visit = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .25 THEN '<25%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Visit = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .50 THEN '25%-50%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Visit = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Visit by RM Quartile"
       , CASE WHEN COUNT(CASE WHEN CAD.Total_Any_DO_Ask = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .25 THEN '<25%'
              WHEN COUNT(CASE WHEN CAD.Total_Any_DO_Ask = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .50 THEN '25%-50%'
              WHEN COUNT(CASE WHEN CAD.Total_Any_DO_Ask = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Asked Major Any DO Quartile"
       , CASE WHEN COUNT(CASE WHEN CRM.Total_RM_Special = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .25 THEN '<25%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Special = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .50 THEN '25%-50%'
              WHEN COUNT(CASE WHEN CRM.Total_RM_Special = 0 THEN NULL ELSE 1 END) / DOP.Portfolio_Size < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Asked Special by RM Quartile"
       , CASE WHEN SUM(PP.Ask_Made) / SUM(PP.Num_Proposals) < .25 THEN '<25%'
              WHEN SUM(PP.Ask_Made) / SUM(PP.Num_Proposals) < .50 THEN '25%-50%'
              WHEN SUM(PP.Ask_Made) / SUM(PP.Num_Proposals) < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Ask Made Proposals Quartile"
       , CASE WHEN SUM(PP.Closed) / SUM(PP.Num_Proposals) < .25 THEN '<25%'
              WHEN SUM(PP.Closed) / SUM(PP.Num_Proposals) < .50 THEN '25%-50%'
              WHEN SUM(PP.Closed) / SUM(PP.Num_Proposals) < .75 THEN '50%-75%'
                ELSE '75%+' END AS "Closed Proposals Quartile"
       , DOP.PQ_Size
       , CASE WHEN DOP.PQ_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PQ_CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) END AS "Total PQ Visited"
       , CASE WHEN DOP.PQ_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PQ_CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) / DOP.PQ_Size END AS "% PQ Visited"
       , CASE WHEN DOP.PQ_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PQ_CRM.Qualified > 0 THEN 1 ELSE NULL END) END AS "Total PQ Qualified"
       , CASE WHEN DOP.PQ_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PQ_CRM.Qualified > 0 THEN 1 ELSE NULL END) / DOP.PQ_Size END AS "% Total PQ Qualified"
       , DOP.PM_Size
       , CASE WHEN DOP.PM_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PM_CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) END AS "Total PM Visited"
       , CASE WHEN DOP.PM_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PM_CRM.Total_RM_Visit > 0 THEN 1 ELSE NULL END) / DOP.PM_Size END AS "% PM Visited"
       , CASE WHEN DOP.PM_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PM_CRM.Qualified > 0 THEN 1 ELSE NULL END) END AS "Total PM Qualified"
       , CASE WHEN DOP.PM_Size = 0 THEN NULL 
         ELSE COUNT(CASE WHEN PM_CRM.Qualified > 0 THEN 1 ELSE NULL END) / DOP.PM_Size END AS "% Total PM Qualified"
       , SYSDATE AS "Date Pulled"
       , '7/1/2015 - 6/30/2017' AS "Data Date Range"
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL POOL 
          ON PROSP.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
     LEFT OUTER JOIN Contacts_RM CRM
          ON Prosp.Prospect_ID = CRM.Prospect_ID
     LEFT OUTER JOIN Contacts_Any_DO CAD
          ON Prosp.Prospect_ID = CAD.Prospect_ID
     LEFT OUTER JOIN Contacts_RM_PQ PQ_CRM
          ON Prosp.Prospect_ID = PQ_CRM.Prospect_ID
     LEFT OUTER JOIN Contacts_RM_PM PM_CRM
          ON Prosp.Prospect_ID = PM_CRM.Prospect_ID
     LEFT OUTER JOIN DO_Portfolio DOP
          ON Prosp.RM_Number = DOP.RM_Number
     LEFT OUTER JOIN GIVING GV
          ON Prosp.Prospect_ID = GV.Prospect_ID
     LEFT OUTER JOIN Proposals PP
          ON Prosp.Prospect_ID = PP.Prospect_ID
     LEFT OUTER JOIN DO_Team DT
          ON Prosp.RM_Number = DT.ASSIGNMENT_ID_NUMBER
GROUP BY Prosp.RM_Name, Prosp.RM_Number, DOP.Portfolio_Size, DOP.PQ_Size, DOP.Office, DOP.Unit, DOP.Time_as_DO, DOP.DO_Type, DOP.PM_Size, DT.Team_Member_Size
ORDER BY Prosp.RM_Name
