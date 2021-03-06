

library(shiny)
library(DBI)
library(ggplot2)
library(pool)


#myserver <- ifelse(Sys.info()["nodename"]=="INFRA035",".",".\\snapman") 
con <-  dbPool(drv = odbc::odbc(),  Driver = 'Sql Server',Server = ".\\snapman",Database = 'Test',Trusted_Connection='yes')

my_ui <- fluidPage(sidebarPanel(sliderInput("cpu_slider","Minutes Back",0,256,256))
                   , mainPanel(plotOutput("cpuPlot")))

my_server <- function(input, output) {
  
  output$cpuPlot <- renderCachedPlot({
    
    
    
    myquery <- paste0("DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info WITH (NOLOCK)); 
   
  SELECT TOP(256)   DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event_Time] ,
                 100 - SystemIdle AS [CPU_Utilization]
  FROM (SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
              record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
              AS [SystemIdle], 
              record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
              AS [SQLProcessUtilization], [timestamp] 
        FROM (SELECT [timestamp], CONVERT(xml, record) AS [record] 
              FROM sys.dm_os_ring_buffers WITH (NOLOCK)
              WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
              AND record LIKE N'%<SystemHealth>%') AS x) AS y 
              Where DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) >= DATEADD(minute,-",input$cpu_slider,",Getdate())
  ORDER BY record_id DESC;
  ")
    mydata <- dbGetQuery(con,myquery)
 
    
    ggplot(mydata,aes(Event_Time,CPU_Utilization)) + geom_line()
    
    
  },cacheKeyExpr = {input$cpu_slider})
}

shinyApp(ui = my_ui, server = my_server)