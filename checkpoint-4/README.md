Content Author: Ashley Quiterio with support from Dr. Jennie Rogers.

Data: Chicago Police Department Data accessed from the Citizens Police Data Project. 
More about this data can be found here: 
http://users.eecs.northwestern.edu/~jennie/courses/data-science-seminar/cpdb-schema/index.html

The following SQL queries provide the data to be used within the machine learning models in 
the following questions. They try to get at potential patterns in police presence across 
Chicago police districts. There are 2 parts to this exploration:

    Q1: Quantile dot plots: When discussing quantile dot plots, I reference this code about 
    making them. Pulling from their paper, Matthew Kay, Tara Kola, Jessica Hullman, Sean Munson, 
    created this tool to think about distributions of event likelihood. I am able to explore the 
    question of officer density in areas. I was curious if we could predict or better understand 
    the range of officer density at the district level within a day? Using quantile dot plots, I 
    will predict/estimate how many officers are in a district on any given day using the number of 
    officers in relation to the population size, district area, and time spent. Note: The code for 
    part 1 goes into the logic for the R markdown code to explore quantile dot plots. 
    Or, you can consider the last full table in part 1 for similar dimensions. 

    Q2: From part 1, I am exploring how officers might be distributed across a space over time. I am 
    then curious how might officers be spending their time. Although we do not have an in depth look 
    into where they were, a dimension of the time they spent in the district is reflected in the number 
    of allegation counts they received. I will use a decision tree model to predict whether officers 
    received at least one allegation in their time based on their average number of hours spent on duty
    in a given year. The question is answered within this Google COLAB notebook: 
    https://colab.research.google.com/drive/1_MKHDa6B8_fG8j9u5j0sPxNDbVNLZjHr?usp=sharing
    which uses data that is first generated from the sql code in src.sql. Or, you can find the ipython 
    notebook with the checkpoint-4 folder under src.ipynb.

Explanations to these questions are within the findings.pdf. Please note that some of the code in 
later questions references temporary tables created in earlier questions, so please run the code in 
order and run all code in that question together. Also, since a few of the queries work with the 
data_officerassignmentattendance table, which has over 18 million cases, there is slightly longer run 
time. 