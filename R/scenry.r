examples.green.paradox = function() {
  setwd("D:/libraries/EconCurves/EconCurves")
  set.restore.point.options(display.restore.point = TRUE)

  add.restore.point.test(scenario.test = function(env,name,...) {
    if (exists("em",env,inherits = FALSE)) {
      if (is.null(env$em) & name != "init.story") {
        stop("em is null")
      }
    }
  })


  ES = initEconStories()
  em = load.model("GreenParadox")
  em = load.model("GreenParadox5")
  init.model(em)
  init.model.scen(em)
  sim = simulate.model(em,init.scen = FALSE)
  sim$scenario = "baseline"
  eval(quote(all(R == alpha*intreaty*(pmin(q_tr,100-p))+(1-alpha*intreaty)*(100-p))), sim)
  eval(quote(alpha*intreaty*(pmin(q_tr,100-p))+(1-alpha*intreaty)*(100-p)), sim)

  es = load.story("GreenParadox_quiz")

  #options(warn=3)
  sim = init.story(es)
  app = shinyScenryApp(es = es)

  runEventsApp(app,launch.browser = rstudio::viewer)
  runEventsApp(app,launch.browser = TRUE)

  sim = init.scenry.frame(es,2)
  rbind(sim[1,],sim[21,])
  library(ggplot2)

  ggplot(data=sim, aes(x=t,y=R,color=.scen,fill=.scen)) + geom_line(size=1.5)
  ggplot(data=sim, aes(x=t,y=cumR,color=.scen,fill=.scen)) + geom_line(size=1.2)
  ggplot(data=sim, aes(x=t,y=p,color=.scen,fill=.scen)) + geom_line(size=1.2)
  ggplot(data=sim, aes(x=t,y=m,color=.scen,fill=.scen)) + geom_line(size=1.2)
  ggplot(data=sim, aes(x=t,y=m_growth,color=.scen,fill=.scen)) + geom_line(size=1.2)



}



init.scenry = function(es,em=es$em,...) {
  restore.point("init.scenry")
  if (length(es$rcode)>0) {
    ES = getES()
    for (file in es$rcode)
      source(paste0(ES$stories.path,"/",file))
  }
  init.scenry.frame(es,1)

}

scenry.check.question = function(answered, correct, qu,...) {
  restore.point("scenry.check.question")
  #cat("\nGiven answer was ", correct)
  if (!answered) {
    txt = "You have not yet answered the question."
    html = HTML(txt)
  } else {

    txt = as.character(qu$expl)
    if (correct) {
      txt = paste0("<b>Correct!</b> ", txt)
    } else {
      txt = paste0("<b>Not correct.</b> ",txt)
    }
    txt = compile.frame.txt(txt)
    html = wellPanel(HTML(txt))
  }
  setUI(qu$explId,html)
}

init.scenry.frame.questions = function(frame) {
  restore.point("init.scenry.frame.questions")

  # init statements
  qu.ind.base = 0
  frame$stas = lapply(seq_along(frame$statements), function(ind) {
    st = init.statement(frame$statements[[ind]],qu.ind = ind+qu.ind.base)
    st$ui = statement.ui(st = st, check.fun=scenry.check.question)
    st
  })



  ui.li = lapply(frame$stas, function(st) st$ui)

  qu.ind.base = qu.ind.base + length(frame$stas)+1
  if (!is.null(frame[["quiz"]])) {
    frame$quizes = lapply(seq_along(frame$quiz), function(i) {
      qu = frame$quiz[[i]]
      qu = init.quiz(qu, quiz.id = paste0("scenry_quiz__",i))
      qu$ui = quiz.ui(qu,in.well.panel = FALSE)
      add.quiz.handlers(qu=qu,check.fun = scenry.check.question,set.ui=FALSE)
      qu
    })
    qu.ui.li = lapply(frame$quizes, function(qu) qu$ui)
    ui.li = c(ui.li, qu.ui.li)
  }

  names(ui.li) = NULL
  frame$qu.ui = ui.li
  if (length(frame$qu.ui)==0) frame$qu.ui = NULL
  frame
}

init.scenry.frame = function(es, frame.num=es$cur$frame.num) {
  restore.point("init.scenry.frame")
  es$cur$frame.num = frame.num

  baseline = es$scenario

  frame = es$frames[[frame.num]]

  frame = init.scenry.frame.questions(frame)

  if (!is.null(frame[["scens"]])) {
    scens = lapply(frame$scens, function(scen) {
      customize.baseline(baseline, scen=scen)
    })
  } else if (!is.null(frame[["params"]])) {
    params = scenry.parse.params(frame$params)

    grid = expand.grid(params)
    scens = lapply(1:NROW(grid), function(i) {
      customize.baseline(baseline, params=grid[i,])
    })
    names(scens) = paste0("scen", seq_along(scens))
  } else {
    scens = list(baseline=baseline)
  }
  es$scens = scens

  # Simulate all scenarios
  es$sim.li = simulate.scenarios(es$em, scens, return.list=TRUE)
  es$sim = es$em$sim = bind_rows(es$sim.li)

  es$cur$frame = frame

  invisible(es$sim)
}


#' Simulate multiple scenarios
#'
#' @param em the model
#' @param scens a list of scenarios
#' @param scen.params A list with different parameters used in the different scenarios
#' @param base.scen The basic scenario which specifies all the parameters that are not changed by scen.params
#' @param lapply.fun the lapply function, may change e.g. to mcapply to simulate scenarioes parallely on a multicore.
simulate.scenarios = function(em, scens=NULL, scen.params=NULL, baseline=em$scenario, return.list=FALSE,lapply.fun = lapply) {
  restore.point("simulate.scenarios")

  if (is.null(scens) & !is.null(scen.params)) {
    grid = expand.grid(scen.params)
    scens = lapply(1:NROW(grid), function(i) {
      customize.baseline(baseline, params=grid[i,])
    })
    names(scens) = paste0("scen", seq_along(scens))
  }

  sim.li = lapply.fun(seq_along(scens), function(i) {
    restore.point("simulate.scenarios.inner")
    scen.name = names(scens)[i]
    scen = scens[[i]]
    sim = simulate.model(em=em, scen=scen,init.scen = TRUE)
    sim = cbind(data.frame(scenario = scen.name), sim)
    sim
  })
  if (return.list) return(sim.li)
  bind_rows(sim.li)
}

customize.baseline = function(baseline, scen=NULL, params=list()) {
  restore.point("customize.baseline")


  new.scen = baseline

  if (length(params)==0) {
    params[names(scen$params)] = scen$params
  }
  new.scen$params = overwrite.defaults(new.scen$params, params)
  new.scen$axis = overwrite.defaults(new.scen$axis, scen$axis)

  new.scen
}

overwrite.defaults = function(defaults, new) {
  defaults[names(new)] = new
  defaults
}




shinyScenryApp = function(es,...) {
  restore.point("shinyStoryApp")

  library(shinyEvents)
  library(shinyAce)
  library(shinyBS)

  app = eventsApp()
  app$es = es
  ui = scenry.ui()
  ui = fluidPage(title = es$storyId,ui)

  appInitHandler(initHandler = function(app,...) {
    restore.point("app.initHandler")
    app$es = as.environment(as.list(es))
  }, app=app)

  app$ui = ui
  scenry.show.frame(app = app,frame.num = 1, init.frame=TRUE)
  app
}


scenry.ui = function(app=getApp(), scela) {
  restore.point("scela.ui")
  ui = list(
    column(5,
      actionButton("scenryPrevBtn","<"),
      actionButton("scenryNextBtn",">"),
      actionButton("scenryForwardBtn",">>"),
      uiOutput("scenryTellUI")
    ),
    column(7,
      uiOutput("scenryOutputUI")
    )
  )
  buttonHandler("scenryNextBtn", scenry.next.btn.click)
  buttonHandler("scenryForwardBtn", scenry.forward.btn.click)
  buttonHandler("scenryPrevBtn", scenry.prev.btn.click)
  buttonHandler("scenryExitBtn", exit.to.main)

  ui
}


scenry.run.btn.click = function(app=getApp(), es=app$es,...) {
  restore.point("scenry.run.btn.click")
  res = scenry.set.params()
  restore.point("scenry.run.btn.click2")
  scenry.show.frame(es=es,frame.num=es$cur$frame.num, init.frame=TRUE)
}


scenry.forward.btn.click = scenry.next.btn.click = function(app=getApp(), es=app$es,...) {
  restore.point("scenry.next.btn.click")

  if (es$cur$frame.num == length(es$frames)) return()

  es$cur$frame.num = es$cur$frame.num +1
  scenry.show.frame(es=es,frame.num=es$cur$frame.num, init.frame=TRUE)
}


scenry.prev.btn.click = function(app=getApp(), es=app$es,...) {
  restore.point("scenry.prev.btn.click")

  if (es$cur$frame.num == 1) return()

  es$cur$frame.num = es$cur$frame.num -1
  scenry.show.frame(es=es,frame.num=es$cur$frame.num, init.frame=TRUE)
}


scenry.show.frame = function(app=getApp(),es=app$es, frame.num = es$cur$frame.num, init.frame=!identical(es$cur$frame.num,frame.num)) {
  restore.point("scenry.show.frame")

  es$cur$frame.num = frame.num
  if (init.frame) {
    init.scenry.frame(es = es)
    frame = es$cur$frame
  } else {
    frame = es$cur$frame
  }
  # copy simulation into globalenv to facilitate development of plots
  assign("sim",es$sim,envir = globalenv())


  if (is.null(frame$title)) frame$title = ""

  html = compile.frame.txt(c(frame$tell), es=es,out = "html")
  html = paste0("<h4>", frame.num," ", frame$title, "</h4>", html)

  params.ui = scenry.frame.params.ui(es=es,frame.num = frame.num)

  tell.ui = list(
    HTML(html),
    params.ui,
    actionButton("scenryRunBtn","Run")
  )

  if (length(frame$background)>0) {
    bg.ui = compile.frame.txt(c(frame$background), es=es,out = "html")
    bg.ui = paste0("<h4>", frame.num," ", frame$title, "</h4>", bg.ui)
    bg.ui = HTML(bg.ui)
  } else {
    bg.ui = NULL
  }

  tabs = list(
    tabPanel(title = "Sim", tell.ui)
  )
  if (!is.null(frame$qu.ui)) {
    tabs = c(tabs,list(tabPanel(title = "Quiz", frame$qu.ui)))
  }
  if (!is.null(bg.ui)) {
    tabs = c(tabs,list(tabPanel(title = "Background", bg.ui)))
  }
  tabs = c(tabs, list(
    tabPanel(title = "Baseline"),
    tabPanel(title = "Model",
      aceEditor("scenryModelYamlAce",value = es$em$yaml, mode="yaml")
    )
  ))

  tabset = do.call(tabsetPanel, tabs)

  setUI(id = "scenryTellUI", tabset)

  buttonHandler("scenryRunBtn", scenry.run.btn.click)

  # Show plots
  output.ui = scenry.frame.output.ui(es=es, frame.num = frame.num)
  setUI(id = "scenryOutputUI",output.ui)
  for (i in seq_along(es$plots)) {
    plotId = names(es$plots)[i]
    setPlot(id = plotId, es$plots[[i]], quoted=TRUE)
  }


}

scenry.frame.output.ui = function(app= getApp(),es=app$es, frame.num = es$cur$frame.num) {
  restore.point("scenry.output.ui")
  frame = es$frames[[frame.num]]

  plots = frame$plots
  if (is.null(plots)) {
    plots = es$defaults$plots
  }
  ref = names(plots)

  rc = ref.to.rowcol(ref)

  col.share = round((rc$colspan / max(rc$end.col)*100))

  frame$plotIds = sc("scenryPlot_",seq_along(plots),"__",col.share)
  names(plots) = frame$plotIds

#  names(plots) = sc("scenryPlot_",seq_along(plots))


  if (length(plots)==0) {
    es$plots = NULL
    return(NULL)
  }

  plots = lapply(plots, function(plot.txt) {
    if (!has.substr(plot.txt,"(")) { #)
      new.txt = paste0(plot.txt,"(es$sim)")
      plot = parse.as.call(new.txt)
    } else {
      plot = parse.as.call(plot.txt)
      plot = substitute.call(plot,list(. = quote(es$sim)))
    }
  })
  es$plots = plots



  li = lapply(seq_along(plots), function(i) {
    plotId = frame$plotIds[[i]]
    clickId = paste0("scenryPlot_",i,"__click")
    #changeHandler(id=clickId, shiny.pane.click, pane.name=pane$name)
    plotOutput(outputId = plotId,click = clickId, width="100%",height="250px")
    #plotOutput(outputId = plotId,click = clickId, width="auto",height="auto")
  })
  names(li) = NULL
  ui = HTML(html.table(li,ref=ref,ncol=2))

  return(ui)
}

scenry.frame.params.ui = function(app= getApp(),es=app$es, frame.num = es$cur$frame.num) {
  restore.point("scenry.params.ui")


  frame = es$frames[[frame.num]]
  if (is.null(frame$params) & is.null(frame$scens)) return(NULL)
  if (!is.null(frame$scens)) {
    li = lapply(frame$scens, function(scen) scen$params)
    yaml = as.yaml(li)
  } else {
    yaml = as.yaml(frame$params)
  }
  txt = sep.lines(yaml)
  fontSize = 12
  height = max((fontSize * 1.5) * length(txt),30)
  aceEditor("scenryParamsEdit",value=yaml,mode="yaml", showLineNumbers = FALSE,height=height,debounce = 10)
}

scenry.set.params = function(app= getApp(),es=app$es) {
  restore.point("scenry.set.params")

  frame.num = es$cur$frame.num
  frame = es$frames[[frame.num]]
  if (is.null(frame$params) & is.null(frame$scens)) {
    cat("\n\n\n EARLY RETURN...", "\n\n\n")
    return(NULL)
  }
  yaml = getInputValue("scenryParamsEdit")
  cat("\n\n\n yaml:", yaml, "\n\n\n")

  li = read.yaml(text = yaml)

  restore.point("scenry.set.params2")

  if (!is.null(frame$scens)) {
    for (sc in intersect(names(li), names(frame$scens))) {
      vals = scenry.parse.params(li[[sc]])
      frame$scens[[sc]]$params[names(li[[sc]])] = vals
    }
  } else {
    vals = scenry.parse.params(li)
    frame$params[names(li)] = li
  }
  es$frames[[frame.num]] = frame
}

scenry.parse.params = function(li) {
  restore.point("scenry.parse.params")
  li = lapply(li, safe_parse_eval_number)
  li
}

compile.frame.txt = function(txt, es=NULL, out="html") {
  if (out=="text") {
    txt = gsub("$","",txt, fixed=TRUE)
  } else if (out=="html") {
    txt = markdownToHTML(text=txt,encoding = "UTF-8", fragment.only=TRUE)
    #Encoding(txt) <- "UTF-8"
    txt
  }
  txt
}

scenPlot = function(sim,x,y,t=1,size=1.2, color="black",title=NULL,...) {
  myt = t
  d = filter(sim, t==myt)
  library(ggplot2)
  p = ggplot(data=d, aes_string(x=x,y=y)) + geom_line(size=size, color=color)
  if (!is.null(title)) p = p + ggtitle(title)
  p
}
