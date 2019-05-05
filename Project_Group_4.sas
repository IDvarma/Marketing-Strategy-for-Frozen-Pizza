/* Group -4 */
/* Marketing Analytics with SAS */

/* Import Grocery Store data */

DATA GROCERY_STORE;
INFILE "E:\Users\dvi170030\Downloads\HW-6\fzpizza\fzpizza_groc_1114_1165" DLM=" " FIRSTOBS=2;
INPUT IRI_KEY WEEK SY GE VEND ITEM UNITS DOLLARS F$ D PR;
RUN;

data GROCERY_STORE1;
SET GROCERY_STORE;
 SY_p=put(SY,z2.);
 format SY z2.;
 GE_p=put(GE,z2.);
 format GE z2.;
 VEND_p=put(VEND,z5.);
 format VEND z5.;
 ITEM_p=put(ITEM,z5.);
 format ITEM z5.;
 UPC = catx('-',SY_p ,GE_p,VEND_p ,ITEM_p);
run;

proc print data=grocery_store1(obs=5);run;

/* Panel_Grocery */

proc import datafile = "E:\Users\dvi170030\Downloads\HW-6\fzpizza\fzpizza_PANEL_GR_1114_1165.dat"
out = panel_gr
dbms = tab replace;
delimiter = '09'x;
getnames = yes;
run;
proc print data=panel_gr(obs=5);run;

/* Import prod_fpizza data */

PROC IMPORT OUT= WORK.Product 
            DATAFILE= "E:\Users\dvi170030\Downloads\HW-6\fzpizza\prod_fpizza.xls" 
            DBMS=EXCEL REPLACE;
     RANGE="Sheet1$"; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
     SCANTIME=YES;
RUN;

/* Import prod_fpizza data updated */

PROC IMPORT OUT= WORK.Product_copy 
            DATAFILE= "E:\Users\dvi170030\Downloads\HW-6\fzpizza\prod_fpizza - Copy.xls" 
            DBMS=EXCEL REPLACE;
     RANGE="Sheet1$"; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
     SCANTIME=YES;
RUN;

DATA PRODUCT1_copy;
SET PRODUCT_copy;
UPC2 = input(UPC1,BEST32.);
RUN;
proc print data=Product_copy(obs=5);run;


/* Import Customer Demographics */
proc import datafile = "E:\Users\dvi170030\Downloads\HW-6\fzpizza\ads_demo3.csv"
out = demo3
dbms = csv replace;
getnames = yes;
run;
proc print data=demo3(obs=5);run;

/* Join Demo3 and Panel_Gr */
PROC SQL;
 CREATE TABLE Panel_Demo_GR AS
 SELECT *
 FROM Panel_gr A JOIN Demo3 B
 ON (A.PANID = B.Panelist_ID);
QUIT;
proc print data=panel_demo_gr(obs=5);run;

/* Join Panel_GR, Demo3, Product */

PROC SQL;
 CREATE TABLE Panel_Demo_Product AS
 SELECT *
 FROM Panel_demo_gr A JOIN Product1_copy  B
 ON (A.COLUPC = B.UPC2);
QUIT;

/* Join Grocery_store & Product */
PROC SQL;
CREATE TABLE Groc_Store_prod AS
SELECT * from GROCERY_STORE1 A JOIN Product B
ON (A.UPC = B.UPC);
QUIT;


/* Join Groc_store_prod & Delivery Stores */

PROC SQL;
CREATE TABLE Groc_Store_prod_Delivery AS
SELECT * from Groc_Store_prod A JOIN Stores_Demo B
ON (A.IRI_KEY = B.IRI_KEY);
QUIT;


/* Sampling */
PROC SURVEYSELECT DATA=Groc_Store_prod_Delivery OUT=GSPD METHOD=SRS
  SAMPRATE=0.2 SEED=1234567;
  RUN;

  /* Market_Share */

PROC SQL;
	CREATE TABLE  Y1 AS
	SELECT L5,sum(DOLLARS) as TOTAL_DOLLARS
	FROM GSPD
	GROUP BY L5;
PROC SQL;
	CREATE TABLE GSPD1_MARKET_SHARE AS
	SELECT L5,TOTAL_DOLLARS/SUM(TOTAL_DOLLARS)*100 as market_share
	FROM Y1
	ORDER BY market_share DESC;
QUIT;

proc print data=GSPD1_MARKET_SHARE;run;

data GSPD2;
set GSPD;
IF L5='DI GIORNO' THEN BRAND = 'DI GIORNO';
ELSE IF L5="TOMBSTONE" THEN BRAND = "TOMBSTONE";
ELSE IF L5="RED BARON" THEN BRAND = "RED BARON";
ELSE IF L5="FRESCHETTA" THEN BRAND = "FRESCHETTA";
ELSE BRAND = 'OTHERS';
RUN;

/* Calculating Price Equivalence */

PROC SQL;
 CREATE TABLE Y2 AS
 SELECT * ,SUM(UNITS) as TOTAL_SALES
 FROM GSPD2 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;

DATA GSPD3;
SET Y2;
PR_PER_OZ = (DOLLARS/UNITS)/VOL_EQ;
PRICE_WT = (PR_PER_OZ*UNITS)/TOTAL_SALES;
RUN;


proc print data=panel_demo_product1(obs=5);run;

/* Logistic Regression */
data panel_demo_product_TOMBSTONE;
set panel_demo_product;
if L5 = 'TOMBSTONE' then pp =1;
else pp = 0;
run;

PROC LOGISTIC data=panel_demo_product_TOMBSTONE descending;
model pp = Panelist_Type Combined_Pre_Tax_Income_of_HH Family_Size HH_RACE Type_of_Residential_Possession Age_Group_Applied_to_Male_HH
Education_Level_Reached_by_Male Occupation_Code_of_Male_HH Male_Working_Hour_Code Age_Group_Applied_to_Female_HH 
Education_Level_Reached_by_Femal Occupation_Code_of_Female_HH Female_Working_Hour_Code Number_of_Dogs Number_of_Cats Marital_Status 
Number_of_TVs_Used_by_HH Number_of_TVs_Hooked_to_Cable; run;

proc qlim data=panel_demo_product_TOMBSTONE;
model pp = UNITS DOLLARS VOL_EQ Panelist_Type Combined_Pre_Tax_Income_of_HH Family_Size HH_RACE Type_of_Residential_Possession Age_Group_Applied_to_Male_HH
Education_Level_Reached_by_Male Occupation_Code_of_Male_HH Male_Working_Hour_Code Age_Group_Applied_to_Female_HH 
Education_Level_Reached_by_Femal Occupation_Code_of_Female_HH Female_Working_Hour_Code Number_of_Dogs Number_of_Cats Marital_Status 
Number_of_TVs_Used_by_HH Number_of_TVs_Hooked_to_Cable / discrete (dist = logit);
output out=mdx marginal;
run;

proc means data=mdx mean std;
run;

/* Multinomial Logit */
Data panel_demo_product1;
set panel_demo_product;
IF L5='DI GIORNO' THEN BRAND = 'DI GIORNO';
ELSE IF L5="TOMBSTONE" THEN BRAND = "TOMBSTONE";
ELSE IF L5="RED BARON" THEN BRAND = "RED BARON";
ELSE IF L5="FRESCHETTA" THEN BRAND = "FRESCHETTA";
ELSE BRAND = 'OTHERS';
RUN;


proc logistic data = panel_demo_product1;
class brand (ref = "OTHERS")/param = ref;
model brand = units dollars Vol_EQ Combined_Pre_Tax_Income_of_HH HH_RACE Type_of_Residential_Possession Children_Group_Code Family_Size
Age_Group_Applied_to_Male_HH Education_Level_Reached_by_Male Occupation_Code_of_Male_HH Male_Working_Hour_Code 
Age_Group_Applied_to_Female_HH Education_Level_Reached_by_Femal Occupation_Code_of_Female_HH Female_Working_Hour_Code
Number_of_Dogs Number_of_Cats Marital_Status Number_of_TVs_Used_by_HH Number_of_TVs_Hooked_to_Cable / link = glogit;
run;

proc sort data=panel_demo_product1 out=test1 nodupkey; by week iri_key;
run;

proc sql;
create table DIGIORNO as select week,avg(dollars) as p1 from panel_demo_product1 where brand = "DI GIORNO" group by week;
quit;

proc sql;
create table TOMBSTONE as select week,avg(dollars) as p2 from panel_demo_product1 where brand = "TOMBSTONE" group by week;
quit;

proc sql;
create table REDBARON as select week,avg(dollars) as p3 from panel_demo_product1 where brand = "RED BARON" group by week;
quit;


proc sql;
create table OTHERS as select week,avg(dollars) as p4 from panel_demo_product1 where brand = "OTHERS" group by week;
quit;


proc sort data=DIGIORNO; by week;
proc sort data=TOMBSTONE; by week;
proc sort data=REDBARON; by week;
proc sort data=FRESCHETTA; by week;
proc sort data=others; by week;
run;

data panel_demo_product2;
set panel_demo_product1;
IF BRAND='DI GIORNO' THEN BRAND1 = 1;
ELSE IF BRAND="TOMBSTONE" THEN BRAND1 = 2;
ELSE IF BRAND="RED BARON" THEN BRAND1 = 3;
ELSE IF BRAND = "FRESCHETT" then BRAND1 =4;
ELSE BRAND1 = 5;
run;

proc sort data=panel_demo_product2; 
by week;
run;

data a1;
merge panel_demo_product2 (in=aa) DIGIORNO (in=bb) TOMBSTONE(in=cc) REDBARON(in=dd) OTHERS(in=ee);
if aa; by week;
run;

data newdata ;
set a1;
array pvec{5} p1 - p5;
retain tid 0;
tid+1;
do i = 1 to 5;
mode=i;
dollar=pvec{i};
decision=(brand1=i);
output;
end;
run;

proc print data=newdata(obs=10);run;

data newdata1;
set newdata;
br2=0;
br3=0;
br4=0;
br5=0;
if mode = 2 then br2 = 1;
if mode = 3 then br3 = 1;
if mode = 4 then br4 = 1;
if mode = 5 then br5 = 1;
inc2=Combined_Pre_Tax_Income_of_HH*br2;
inc3=Combined_Pre_Tax_Income_of_HH*br3;
inc4=Combined_Pre_Tax_Income_of_HH*br4;
inc5=Combined_Pre_Tax_Income_of_HH*br5;
Children_Group_Code2=Children_Group_Code*br2;
Children_Group_Code3=Children_Group_Code*br3;
Children_Group_Code4=Children_Group_Code*br4;
Children_Group_Code5=Children_Group_Code*br5;
Family_Size2=Family_Size*br2;
Family_Size3=Family_Size*br3;
Family_Size4=Family_Size*br4;
Family_Size5=Family_Size*br5;

Type_Residence2 = Type_of_Residential_Possession*BR2;
Type_Residence3 = Type_of_Residential_Possession*BR3;
Type_Residence4 = Type_of_Residential_Possession*BR4;
Type_Residence5 = Type_of_Residential_Possession*BR5;

Age_grp_M2 = Age_Group_Applied_to_Male_HH*BR2;
Age_grp_M3 = Age_Group_Applied_to_Male_HH*BR3;
Age_grp_M4 = Age_Group_Applied_to_Male_HH*BR4;
Age_grp_M5 = Age_Group_Applied_to_Male_HH*BR5;

Ed_level_Male2 = Education_Level_Reached_by_Male*BR2;
Ed_level_Male3 = Education_Level_Reached_by_Male*BR3;
Ed_level_Male4 = Education_Level_Reached_by_Male*BR4;
Ed_level_Male5 = Education_Level_Reached_by_Male*BR5;

Occ_code_M2 = Occupation_Code_of_Male_HH*BR2;
Occ_code_M3 = Occupation_Code_of_Male_HH*BR3;
Occ_code_M4 = Occupation_Code_of_Male_HH*BR4;
Occ_code_M5 = Occupation_Code_of_Male_HH*BR5;

M_work_hr_code2 = Male_Working_Hour_Code*BR2;
M_work_hr_code3 = Male_Working_Hour_Code*BR3;
M_work_hr_code4 = Male_Working_Hour_Code*BR4;
M_work_hr_code5 = Male_Working_Hour_Code*BR5;



Age_grp_F2 = Age_Group_Applied_to_Female_HH*BR2;
Age_grp_F3 = Age_Group_Applied_to_Female_HH*BR3;
Age_grp_F4 = Age_Group_Applied_to_Female_HH*BR4;
Age_grp_F5 = Age_Group_Applied_to_Female_HH*BR5;

Ed_level_Female2 = Education_Level_Reached_by_Femal*BR2;
Ed_level_Female3 = Education_Level_Reached_by_Femal*BR3;
Ed_level_Female4 = Education_Level_Reached_by_Femal*BR4;
Ed_level_Female5 = Education_Level_Reached_by_Femal*BR5;

Occ_code_F2 = Occupation_Code_of_Female_HH*BR2;
Occ_code_F3 = Occupation_Code_of_Female_HH*BR3;
Occ_code_F4 = Occupation_Code_of_Female_HH*BR4;
Occ_code_F5 = Occupation_Code_of_Female_HH*BR5;

F_work_hr_code2 = Female_Working_Hour_Code*BR2;
F_work_hr_code3 = Female_Working_Hour_Code*BR3;
F_work_hr_code4 = Female_Working_Hour_Code*BR4;
F_work_hr_code5 = Female_Working_Hour_Code*BR5;

Dogs_count2 = Number_of_Dogs*BR2;
Dogs_count3 = Number_of_Dogs*BR3;
Dogs_count4 = Number_of_Dogs*BR4;
Dogs_count5 = Number_of_Dogs*BR5;

Cats_count2 = Number_of_Cats*BR2;
Cats_count3 = Number_of_Cats*BR3;
Cats_count4 = Number_of_Cats*BR4;
Cats_count5 = Number_of_Cats*BR5;

run;

proc means data = newdata1 N NMISS;run;

proc mdc data=newdata1;
model decision = br2 br3 br4 br5 inc2-inc5 Family_Size2-Family_Size5 Children_Group_Code2-Children_Group_Code5
HH_RACE2-HH_RACE5 Type_Residence2-Type_Residence5 Age_grp_M2-Age_grp_M5 
Ed_level_Male2-Ed_level_Male5 Occ_code_M2-Occ_code_M5 M_work_hr_code2-M_work_hr_code5
Ed_level_Female2-Ed_level_Female5 Occ_code_F2-Occ_code_F5 F_work_hr_code2-F_work_hr_code5
Number_of_Dogs Number_of_Cats / type=clogit 
nchoice=5;
id tid;
output out=probdata pred=p;
run;

proc means data=newdata n NMISS;run;


proc anova data=panel_demo_product1;
class Marital_status panelist_type;
model dollars = marital_status panelist_type;
run;

/*********Survival Analysis****************/
data qq1;
set panel_demo_product1;
keep PANID WEEK L5 BRAND;
run;

proc sort data=qq1;by WEEK;run;

proc print data=qq1(obs=5);run;

PROC EXPORT data=qq1 OUTFILE = 'E:\Users\dvi170030\Downloads\HW-6\fzpizza\final2.txt' DBMS=TAB REPLACE ; 
PUTNAMES=YES;RUN;

DATA qq2;
SET qq1;
if BRAND= 'TOMBSTONE' then flag=1; else flag=0;
RUN;

proc SQL;
create table qq3 AS
select WEEK, sum(flag) from qq2
group by WEEK;
quit;


 PROC SQL;
 CREATE TABLE survival1 AS
 SELECT *
 FROM qq1 
 where week >= (SELECT min(week) from qq1) and week < (SELECT min(week)+21 from qq1);
QUIT;

DATA survival2;
SET survival1;
if BRAND= 'TOMBSTONE' then flag=1; else flag=0;
RUN;


DATA TOM_surv;
SET survival2;
WHERE BRAND= 'TOMBSTONE';
RUN;

PROC SQL;
 CREATE TABLE survival11 AS
 SELECT *
 FROM qq1 
 where week >= (SELECT min(week)+21 from qq1) and week < (SELECT min(week)+41 from qq1);
QUIT;


 PROC SQL;
 CREATE TABLE survival_new AS
 SELECT * FROM survival11 s1 where PANID IN (SELECT PANID from TOM_surv s2);
QUIT;

DATA survival_new1;
SET survival_new;
if BRAND= 'TOMBSTONE' then flag=1; else flag=0;
RUN;

PROC SQL;
 SELECT min(week)
 FROM survival_new1;
QUIT;

DATA survival_new2;
SET survival_new1;
week1= week-1134;
RUN;

proc lifetest data=survival_new2;
time week1*flag(0);
run;

DATA survival_man;
SET survival_new;
if BRAND= 'TOMBSTONE' then flag=1;
ELSE IF BRAND="DI GIORNO" THEN flag = 2;
ELSE IF BRAND="RED BARON" THEN flag = 3;
ELSE flag = 4;
RUN;

proc freq data=survival_man;
table flag;run;

/**** Panel Regression ****/

proc print data=GSPD2(obs=5);run;

data sales_final;
set GSPD3;
if BRAND = "DI GIORNO" then BR_1 = 1; ELSE BR_1 = 0;
if BRAND = "TOMBSTONE" then BR_2 = 1; ELSE BR_2 = 0;
if BRAND = "RED BARON" then BR_3 = 1; ELSE BR_3 = 0;
if BRAND = "FRESCHETT" then BR_4 = 1; ELSE BR_4 = 0;

if F = "A" THEN fA = 1; ELSE fA = 0;
if F = "A+" then fAP = 1; ELSE fAP = 0;
if F = "B" then fB =1; ELSE fB = 0;
if F = "C" then fC = 1; ELSE fC = 0;

if d=1 then dminor=1; else dminor=0;
if d=2 then dmajor=1; else dmajor=0;

weight = UNITS/TOTAL_SALES;
fA_wt = fA*weight;
fB_wt = fB*weight;
fC_wt = fC*weight;
fAP_wt = fAP*weight;

dminor_wt = dminor*weight;
dmajor_wt = dmajor*weight;
PR_wt = PR*weight;

Tot_Volume = UNITS*VOL_EQ;

run;

PROC SQL;
 CREATE TABLE sales_final1 AS
 SELECT IRI_KEY,WEEK,BRAND, SUM(UNITS) as UNITS1, SUM(DOLLARS) as DOLLARS1, SUM(PRICE_WT) as PRICE_WGT, SUM(fA_wt) as fA_wgt, 
	SUM(fAP_wt) as  fAP_wgt,SUM(fB_wt)as fB_wgt, SUM(fC_wt) as fC_wgt, SUM(dminor_wt) as  dminor_wgt,
	SUM(dmajor_wt) as dmajor_wgt, SUM(PR_wt) as PR_wgt, SUM(Tot_Volume) as Total_Vol
 FROM sales_final 
 GROUP BY IRI_KEY,WEEK,BRAND;
QUIT;


proc transpose data=sales_final1 out=wide11 prefix=UNITS1;
   by IRI_KEY WEEK;
   id BRAND;
   var UNITS1;
run;
proc transpose data=sales_final1 out=wide21 prefix=DOLLARS1;
   by IRI_KEY WEEK;
   id BRAND;
   var DOLLARS1;
run;
proc transpose data=sales_final1 out=wide31 prefix=PRICE_WGT;
   by IRI_KEY WEEK;
   id BRAND;
   var PRICE_WGT;
run;

proc transpose data=sales_final1 out=wide41 prefix=fA_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var fA_wgt;
run;
proc transpose data=sales_final1 out=wide51 prefix=fAP_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var fAP_wgt;
run;
proc transpose data=sales_final1 out=wide61 prefix=fB_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var fB_wgt;
run;
proc transpose data=sales_final1 out=wide71 prefix=fC_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var fC_wgt;
run;
proc transpose data=sales_final1 out=wide81 prefix=dminor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dminor_wgt;
run;
proc transpose data=sales_final1 out=wide91 prefix=dmajor_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var dmajor_wgt;
run;
proc transpose data=sales_final1 out=wide101 prefix=PR_wgt;
   by IRI_KEY WEEK;
   id BRAND;
   var PR_wgt;
run;
proc transpose data=sales_final1 out=wide112 prefix=Tot_Vol;
   by IRI_KEY WEEK;
   id BRAND;
   var Total_Vol;
run;


data widef_groc;
    merge  wide11(drop=_name_) wide21(drop=_name_) wide31(drop=_name_) wide41(drop=_name_) wide51(drop=_name_)
           wide61(drop=_name_) wide71(drop=_name_) wide81(drop=_name_) wide91(drop=_name_) wide101(drop=_name_) wide112(drop=_name_);
    by IRI_KEY WEEK;
run;

data grocery_final;
   set widef_groc;
   array change _numeric_;
        do over change;
            if change=. then change=0;
        end;
 run ;

proc print data=grocery_final(obs=10);run;

 DATA Grocery_final_11;
SET Grocery_final;
DF_CC = dmajor_wgtTOMBSTONE*fB_wgtTOMBSTONE;
RUN;

DATA Grocery_final_12;
SET Grocery_final;
DF_CC = dmajor_wgtTOMBSTONE*fB_wgtTOMBSTONE*PR_wgtTOMBSTONE;
RUN;
DATA Grocery_final_14;
SET Grocery_final;
DF_CC = dmajor_wgtTOMBSTONE*fB_wgtTOMBSTONE*PR_wgtTOMBSTONE*PRICE_WGTTOMBSTONE;
RUN;

DATA Grocery_final_13;
SET Grocery_final;
DF_CC = dmajor_wgtDI_GIORNO*fB_wgtDI_GIORNO*PR_wgtDI_GIORNO;
RUN;


Proc panel data=Grocery_final_11;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTTOMBSTONE fA_wgtTOMBSTONE fAP_wgtTOMBSTONE fB_wgtTOMBSTONE fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE /fixone;run;

Proc panel data=Grocery_final_11;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTTOMBSTONE fA_wgtTOMBSTONE fAP_wgtTOMBSTONE fB_wgtTOMBSTONE fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE /ranone;run;

/* Hausman Test P-value is < 0.001 which suggests that FE is better. Further as there is simultanous effect between sales and 
price, there is endogeneity which is corrected only by FE and not RE */

Proc panel data=Grocery_final_11;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTTOMBSTONE fA_wgtTOMBSTONE fAP_wgtTOMBSTONE fB_wgtTOMBSTONE fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE /fixtwo;run;


Proc panel data=Grocery_final_11;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTDI_GIORNO PRICE_WGTRED_BARON PRICE_WGTFRESCHETT PRICE_WGTOTHERS fA_wgtTOMBSTONE fAP_wgtTOMBSTONE fB_wgtTOMBSTONE 
fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE /fixtwo;run;


Proc panel data=Grocery_final_14;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTTOMBSTONE PRICE_WGTDI_GIORNO PRICE_WGTRED_BARON PRICE_WGTFRESCHETT PRICE_WGTOTHERS fA_wgtTOMBSTONE 
fAP_wgtTOMBSTONE fB_wgtTOMBSTONE fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE DF_CC /fixone;run;

Proc panel data=Grocery_final_12;
id IRI_KEY WEEK;
model Tot_VolDI_GIORNO = PRICE_WGTTOMBSTONE PRICE_WGTDI_GIORNO PRICE_WGTRED_BARON PRICE_WGTFRESCHETT PRICE_WGTOTHERS fA_wgtDI_GIORNO 
fAP_wgtDI_GIORNO fB_wgtDI_GIORNO fC_wgtDI_GIORNO dminor_wgtDI_GIORNO dmajor_wgtDI_GIORNO PR_wgtDI_GIORNO /fixone;run;

Proc panel data=Grocery_final_12;
id IRI_KEY WEEK;
model Tot_VolTOMBSTONE = PRICE_WGTTOMBSTONE PRICE_WGTDI_GIORNO PRICE_WGTRED_BARON PRICE_WGTFRESCHETT PRICE_WGTOTHERS fA_wgtTOMBSTONE 
fAP_wgtTOMBSTONE fB_wgtTOMBSTONE fC_wgtTOMBSTONE dminor_wgtTOMBSTONE dmajor_wgtTOMBSTONE PR_wgtTOMBSTONE DF_CC /fixone;run;

Proc means data=Grocery_final_12;run;

PROC SQL;
CREATE TABLE Price_Avg as 
SELECT WEEK,BRAND, avg(PRICE_WT) as Average_Price_per_VOL_EQ from GSPD3
GROUP BY WEEK,BRAND;
quit;

PROC EXPORT data=Price_Avg OUTFILE = 'E:\Users\dvi170030\Downloads\HW-6\fzpizza\final3.txt' DBMS=TAB REPLACE ; 
PUTNAMES=YES;RUN;

PROC SQL;
CREATE TABLE Market_Price_Avg as 
SELECT Market_name,BRAND, avg(PRICE_WT) as Average_Price_per_VOL_EQ from GSPD3
GROUP BY Market_name,BRAND;
quit;

PROC EXPORT data=Market_Price_Avg OUTFILE = 'E:\Users\dvi170030\Downloads\HW-6\fzpizza\final4.txt' DBMS=TAB REPLACE ; 
PUTNAMES=YES;RUN;

PROC SQL;
CREATE TABLE Brand_Price_Avg as 
SELECT BRAND, avg(PRICE_WT) as Average_Price_per_VOL_EQ from GSPD3
GROUP BY BRAND;
quit;

proc print data=Brand_Price_Avg;run;

proc freq data=GSPD3;
table BRAND;run;

proc print data=GSPD3(obs=5);run;

data GSPD_FRESCHETT;
set GSPD3;
where BRAND = "FRESCHETT";run;

PROC SQL;
	CREATE TABLE  X1 AS
	SELECT MARKET_NAME,BRAND,sum(DOLLARS) as TOTAL_DOLLARS
	FROM GSPD3
	GROUP BY MARKET_NAME,BRAND;
PROC SQL;
	CREATE TABLE X2 AS
	SELECT MARKET_NAME,BRAND,TOTAL_DOLLARS/SUM(TOTAL_DOLLARS)*100 as market_share
	FROM X1
	GROUP BY MARKET_NAME
	ORDER BY market_share DESC;
QUIT;

PROC EXPORT data=X2 OUTFILE = 'E:\Users\dvi170030\Downloads\HW-6\fzpizza\final5.txt' DBMS=TAB REPLACE ; 
PUTNAMES=YES;RUN;




/** Factors effecting Sales **/

proc reg data=sales_final;
model dollars = PRICE_WT BR_1 BR_2 BR_3 BR_4 fA FAP FB FC dminor dmajor PR / stb vif ;
run;

proc print data=sales_final(obs=10);run;

data sales_final_TOMBSTONE;
set sales_final;
where BR_2=1;
run;

proc reg data=sales_final_TOMBSTONE;
model dollars = PRICE_WT fA FAP FB FC dminor dmajor PR / stb vif ;
run;
