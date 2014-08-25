ld30pde
=======

Ludum Dare 30 Attempt "Connected Worlds"

Design
=======

The theme stumped me because it seemed to be crying out to have a physics puzzle made for it. Or some stringing things together puzzle.  I wanted to try and do something a bit different.

So I interpreted it as social connections... a person's own world and how they connect to each other.

The idea was to start off as a baby with no connections, then connect with a parent, then more people etc and gradually expand the circles you move in.

As the game progresses more mechanics would get introduced.  So some connections would be harder to get.  Some may be negative.  Some may cause other existing connections to move away from you.  Others influential connections would have people getting close to you to get close to you... perhaps just to get close to that infuential connection.

This was to all be presented in an abstract way through simple flowers that petal count and radius would change.

There would also be an idea of influence.  Where movement inside your existing circle was easy, in your extended circle quite difficult and very difficult outside your extended circle.

Implementation
==============

Well at time of writing just the very first stage where the concept of movement and creating a connection was explored.  I think with another solid push on this many points in the above design could be explored.  Though I'm busy for the next few days so right now that looks unlikely.

Though I may tinker with this some more at some point. Perhaps make it into a zen clicking around thing.  I would be interested in seeing how it runs on an iPad.

I used Google Dart for this project. It wouldn't be suitable for the js1k or other similar code-size restricted competitions because of the high initial overhead - but it was actually expressive and useful for prototyping.  Once I had figured out deployment to gh-pages it was quite enjoyable.

I also tried out a slightly different style of programming then I usually do.  A more data oriented approach so objects were just plain old data and quite specific... meaning object strides in collections should have been quite small.  It was fun trying that out.

Do not use any of the code here as a good example.  I was messing around... normally these kind of experiments I keep to myself and they end up lost in a folder on a hard drive somewhere.  Not sure about the wisdom of sharing all this, but here it is!

Notes
=======
I spent a lot of the first half of the contest getting dart and github pages working nicely together.  I may well use this method again for the next jam... though get it setup all before hand.

Now I have Jekyll somewhat bent to my will for releases I basically did this.
  1. Created the page using the github create project page interface
  2. Checked out the game jam repository twice.  Once for master so I could work there. Then another for the gh-pages branch
  3. Used git flow to manage features and releases
  4. When I had a version I wanted to release, I used git flow release start 0.1.0 and then git flow release finish 0.1.0 so tags were created
  5. pub build
  6. cp -r build/web ../ld30pde-ghpages/v/0.1.0
  7. git push --tags
  8. cd ../ld30pde-ghpages
  9. git add .
  10. git commit -a -m 'web release of 0.1.0'
  11. git push origin gh-pages
  12. cd ../ldpde

There's a few custom things you'll find in the gh-pages to get the version page working.  It is pretty rough but I felt having a way of deploying the game quickly so I could share and get feedback and eventually enter would be really important.

On reflection a few hours prep before hand figuring this out and setting up the repository just right would have meant I would have had more time to complete the game - at least a version 1 playable anyway.

I tried to incorporate a few tips one of my artist friends gave me about strokes and volumes.

As it was all prototype I also kept it all in one file. Though I did have a few spring cleanings as I went along.  I also went for polish over content a few times as I was having fun with that. Like lerping the movement with an ease in & out function.  Movement with the petals.  A pleasing slow rotation.
