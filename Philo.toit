
import log
import gpio
import pixel_strip show *
import bitmap show bytemap_zap
import monitor

// NeoPixel RGB-Led-Ring
GPIO_LED_STRIP ::= 13 // 2 //13
NUM_PIXELS ::= 24
NUM_PHILOSOPHS ::= 5

r := ByteArray NUM_PIXELS
g := ByteArray NUM_PIXELS
b := ByteArray NUM_PIXELS

ledPixels /PixelStrip := ?

PIXELS ::= List NUM_PIXELS: it
PIXELS_PHILOSOPH ::= [4, 8, 12, 16, 20]
PIXELS_LEFT_FORK ::= [6, 10, 14, 18, 22]
PIXELS_RIGHT_FORK ::= [2, 6, 10, 14, 18]


startSignal := monitor.Signal // to start all tasks synchronised


class Fork:
  id /int
  pixel /int
  lock /monitor.Semaphore
  logger_ /log.Logger

  static COLOR_FREE ::= [0,0,8]
  static COLOR_USED ::= [0,0,8]

  constructor --.id/int --.pixel/int:
    logger_ = log.default.with_name "Fork-$(id+1)"
    lock = monitor.Semaphore --count=1 --limit=1
    //display
    //sleep --ms=500
    
  isUsed -> bool:
    return not isFree

  isFree -> bool:
    return lock.count > 0

  take:
    logger_.debug "take"
    lock.down
    display

  give:
    logger_.debug "give"
    lock.up
    display

  display:
    setPixelColor pixel (isFree? COLOR_FREE : COLOR_USED)
    if pixel == PIXELS_RIGHT_FORK[0]:
      setPixelColor PIXELS_LEFT_FORK[4] (isFree? COLOR_FREE : COLOR_USED)
    
    ledPixels.output r g b
    logger_.debug (isFree ? "free" : "used")



class Philosoph:
  static STATE_UNKNOWN /int ::= 0
  static STATE_THINKING /int ::= 1
  static STATE_HUNGRY /int ::= 2
  static STATE_EATING /int ::= 3
  static STATE_FEDUP /int ::= 4

  static COLOR_BLACK ::= [0,0,0]
  static COLOR_ARMS ::= [8,8,8]
  static COLOR_STATE ::= [[0,100,100], [0,255,0], [255,100,0], [255,255,0], [0,64,0]]
  static STATE_MESSAGE ::= [ "absent", "thinking", "hungry", "eating", "fed up"]

  id /int
  leftFork /Fork
  rightFork /Fork
  state /int := STATE_UNKNOWN
  pixel /int
  logger_ /log.Logger


  constructor 
      --.id/int 
      --.leftFork/Fork 
      --.rightFork/Fork
      --.pixel/int
      :
    
    logger_ = log.default.with_name "Phil-$(id+1)"
    
    task := task ::
      display
      leftFork.display
      rightFork.display
      
      logger_.debug "takes a seat"
      startSignal.wait
      while true:
        state = STATE_THINKING
        display
        sleep --ms= 1000 * (random 1 15)

        //---------------------------------------
        state = STATE_HUNGRY
        display
        //sleep --ms=1000

        // how to wait for the forks
        strategy ::= 4
        if strategy == 1:
          takeRightFork
          takeLeftFork
        
        else if strategy == 2:
          takeLeftFork
          takeRightFork

        else if strategy == 3:
          if leftFork.isFree: 
            logger_.debug "left fork free"
            takeLeftFork
            takeRightFork

          else if rightFork.isFree:
            logger_.debug "right fork free"            
            takeRightFork
            takeLeftFork

          else:
            logger_.debug "no fork free"
            takeLeftFork
            takeRightFork

        else if strategy == 4:
          while leftFork.isUsed or rightFork.isUsed:
            //logger_.debug "no fork free"
            sleep --ms=100

          takeRightFork
          takeLeftFork


        //---------------------------------------
        state = STATE_EATING
        display
        sleep --ms= 1000 * (random 5 10)
        // put forks away
        setPixelColor pixel - 1 COLOR_BLACK
        setPixelColor pixel + 1 COLOR_BLACK
        ledPixels.output r g b
        leftFork.give
        rightFork.give

        //---------------------------------------
        state = STATE_FEDUP
        display
        sleep --ms=1000

  takeRightFork:
    rightFork.take
    setPixelColor pixel - 1 COLOR_ARMS
    display

  takeLeftFork:
    leftFork.take
    setPixelColor pixel + 1 COLOR_ARMS
    display    

  display:
    setPixelColor pixel COLOR_STATE[state]
    ledPixels.output r g b
    logger_.debug STATE_MESSAGE[state]


fork := List NUM_PHILOSOPHS
philosoph := List NUM_PHILOSOPHS


setPixelColor pixel/int color/List:
  r[pixel] = color[0]
  g[pixel] = color[1]
  b[pixel] = color[2]
  
testPixels:
  WAIT ::= 50
  NUM_PIXELS.repeat: | pixel |
    setPixelColor pixel [ 255, 0, 0]
    ledPixels.output r g b
    sleep --ms=WAIT

    setPixelColor pixel [ 0, 255, 0]
    ledPixels.output r g b
    sleep --ms=WAIT
    
    setPixelColor pixel [ 0, 0, 255]
    ledPixels.output r g b
    sleep --ms=WAIT

    setPixelColor pixel [ 32, 32, 32]
    ledPixels.output r g b
    
  
  PIXELS.do --reversed: | pixel |
    setPixelColor pixel [ 0, 0, 0]
    ledPixels.output r g b
    sleep --ms=WAIT/2

clearPixels:
  NUM_PIXELS.repeat: | pixel |
    setPixelColor pixel [ 0, 0, 0]



// ==============================================
main:
  ledPixels = PixelStrip.uart NUM_PIXELS --pin=(gpio.Pin GPIO_LED_STRIP)
  //testPixels

  //createForks
  NUM_PHILOSOPHS.repeat:
    fork[it] = Fork --id=it --pixel=PIXELS_RIGHT_FORK[it]

  //createPhilosophs
  NUM_PHILOSOPHS.repeat:
    philosoph[it] = Philosoph 
        --id=it 
        --leftFork=(fork[(it+1) % NUM_PHILOSOPHS])
        --rightFork=fork[it]
        --pixel=PIXELS_PHILOSOPH[it]

  // start it
  sleep --ms=1000

  startSignal.raise
  print "started"