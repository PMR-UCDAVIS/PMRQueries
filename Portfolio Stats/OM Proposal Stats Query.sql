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

select PRPL.PROPOSAL_ID
       , PRPL.PROSPECT_ID
       , PRPL.START_DATE
       , PRPL.STOP_DATe
       , PRPL.ACTIVE_IND
       , PRPL.PROPOSAL_STATUS_CODE
       , PRPL.STAGE_CODE
       , PRPL.ORIGINAL_ASK_AMT
       , PRPL.ASK_AMT
       , PRPL.ANTICIPATED_AMT
       , PRPL.GRANTED_AMT
       , POOL.Abs_High_Capacity_Ucdt_Asks
       , POOL.Abs_High_Capacity_Ucdt_Ask_Lvl
       , PRPL.ASK_AMT - POOL.Abs_High_Capacity_Ucdt_Asks AS "Ask - Capacity"
       , PRPL.INITIAL_CONTRIBUTION_DATE as "Ask Date"
       , PRPL.EXPECTED_DATE as "Close Date"
       , ROUND((PRPL.EXPECTED_DATE - PRPL.INITIAL_CONTRIBUTION_DATE) / 365, 2) as "Years to Close"
       , SYSDATE AS "Date Pulled"
       , '7/1/2015 - 5/15/2017' AS "Data Date Range"
from Prospect_List PROSP
     LEFT OUTER JOIN ADVANCE.PROPOSAL PRPL
            ON PROSP.PROSPECT_ID = PRPL.PROSPECT_ID
            AND PRPL.PROPOSAL_TYPE like 'MG%'
/*Same Prospects from other analysis*/
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL Pool 
          ON PRPL.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
WHERE PRPL.START_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('5/15/2017', 'MM/DD/YYYY')
