/*Grabbing all of the active prospects assigned to Dev Officers*/
WITH Prospect_List as (
Select DISTINCT P.Prospect_Id
       , S.ID_NUMBER AS RM_Number
       , S.SORT AS RM_Name
       , P.STAGE_CODE
       , TMS_S.SHORT_DESC
       , ASGMT.Priority_Code
       , ASGMT.START_DATE AS ASMGT_Start_Date
from ADVANCE.PROSPECT P
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON P.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
     INNER JOIN ADVANCE.STAFF S
           ON ASGMT.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER 
     LEFT OUTER JOIN ADVANCE.Tms_Stage TMS_S
          ON P.STAGE_CODE = TMS_S.STAGE_CODE
WHERE P.ACTIVE_IND = 'Y' 
      and S.ID_NUMBER NOT IN (
          '0000886412'
          , '0000934169'
          , '0000914804'
          , '0000667353'
          , '0000761072'
          , '0000629408'
          , '0000710242'
          , '0001018506' )
      and S.ACTIVE_IND = 'Y'
      and S.STAFF_TYPE_CODE = 'DEV'
      and s.unit_code NOT IN ( 'ASGP', 'FCG' )
)

/*Finding ask date for all prospects*/
, Ask_Date as (
SELECT Prosp.Prospect_Id
       , MIN(CR.Contact_Date) as Ask_Date
       , Prosp.RM_Number
       , Prosp.ASMGT_Start_Date
FROM Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.PROSPECT_ID
             AND Prosp.RM_Number = CR.AUTHOR_ID_NUMBER
             AND CR.CONTACT_PURPOSE_CODE = 'A'
             AND CR.Contact_Date >= Prosp.ASMGT_Start_Date
GROUP BY Prosp.Prospect_ID, Prosp.ASMGT_Start_Date, Prosp.RM_Number
)

/*Finding how many visits before ask made*/
, Visits_to_Ask as (
SELECT A.Prospect_Id
       , COUNT(CR.REPORT_ID) AS Visits
FROM Ask_Date A
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON A.Prospect_Id = CR.PROSPECT_ID
             AND A.RM_Number = CR.AUTHOR_ID_NUMBER
             AND CR.CONTACT_PURPOSE_CODE = 'A'
             AND CR.Contact_Date Between A.ASMGT_Start_Date AND A.Ask_Date
             AND CR.CONTACT_TYPE = 'V'
GROUP BY A.Prospect_Id
)

/*Finding how many prospects have been removed from a portfolio*/
, Removed AS (
SELECT Prosp.RM_Name
       , COUNT(CASE WHEN ASGMT.Stop_Date IS NOT NULL THEN 1 ELSE NULL END) Total_Removed
FROM Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON Prosp.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'N' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
          AND ASGMT.STOP_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('5/15/2017', 'MM/DD/YYYY')
GROUP BY Prosp.RM_Name
)

/*Grabbing portfolio sizes and total PQ prospects for each RM*/
, DO_Portfolio as (
Select  P.RM_Number
        , P.RM_Name
        , COUNT(P.PROSPECT_ID) Portfolio_Size
        , (SELECT COUNT(PROSPECT_ID) FROM Prospect_List PpL WHERE Priority_Code = 'PQ' AND PpL.RM_Number = P.RM_Number) PQ_Size
from Prospect_List P
GROUP BY P.RM_Number, P.RM_Name
)

Select Prosp.Prospect_Id
       , Prosp.RM_Name
       , Prosp.ASMGT_Start_Date as "Assignment Start Date"
       , AD.Ask_Date as "Ask Date"
       , V.Visits as "Visits from Assignment to Ask"
       , ROUND((SYSDATE - Prosp.ASMGT_Start_Date) / 365, 2) as "Years in Portfolio"
       , ROUND((AD.Ask_Date - Prosp.ASMGT_Start_Date) / 365, 2) as "Years from Assignment to Ask"
       , DOP.Portfolio_Size AS "Portfolio Size"
       , R.Total_Removed as "Total Removed"
       , SYSDATE AS "Date Pulled"
       , '7/1/2015 - 5/15/2017' AS "Data Date Range"
FROM Prospect_List Prosp
     LEFT OUTER JOIN Ask_Date AD ON Prosp.Prospect_ID = AD.Prospect_ID
     LEFT OUTER JOIN Visits_to_Ask V ON Prosp.Prospect_ID = V.Prospect_ID
     LEFT OUTER JOIN Removed R ON Prosp.RM_Name = R.RM_Name
     LEFT OUTER JOIN DO_Portfolio DOP ON Prosp.RM_Number = DOP.RM_Number
