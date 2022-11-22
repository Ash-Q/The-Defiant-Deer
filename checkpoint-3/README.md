Content Author: Ashley Quiterio with support from Dr. Jennie Rogers & 496 course staff.

Data: Chicago Police Department Data accessed from the Citizens Police Data Project. 
More about this data can be found here: 
http://users.eecs.northwestern.edu/~jennie/courses/data-science-seminar/cpdb-schema/index.html

The following SQL queries create tables to be exported and used in observablehq.com to create 
interactive visualizations. There are 2 parts to this exploration:

    Q1: I want to understand the relationship between the racial distribution of officers in a
    district with the racial distribution of people that live in the district. Is there a 
    discrepancy between the folks that police a district versus those who live in that district? 
    I am going to do this with a choropleth map that is colored by officers per capita. It will 
    then have a popup for each district and show the racial distribution of officers. This will 
    show the relationship between officers per capita and the racial make-up of officers in a 
    district.

    Q2: To supplement question 1, I will create a bar chart that has race on the x-axis and
    percentage of people on the y-axis. It will have two bars for each race category: one for 
    officers and one for residents. It will have a selection drop down for the districts. 


Both of these visuals can be found here: https://observablehq.com/d/739623968cf9599f
Please note that some of the code in later questions references temporary tables created in 
earlier questions, so please run the code in order and run all code in that question together.