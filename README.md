

# TopoCache


* **Fault**
* **Fix**
* **Cause** and **Effect**
* **Chart** and **Trend**
* **Align**

* **Stampers**
  stamp readers
  stamp writers
  monitors

## Artefacts

* (local, physical, reified) Data Sources (a.k.a. 'flat files', 'text files')

* Program Sources

* Cache Files

* In-Memory Caches

To use cache:

* cache must be present
* cache must be newer than its dependency artefacts


The list of (cache, raw and program) artefacts arranged by their modification dates
must be a proper (monotonic?) sublist of the list of their logical dependencies.

In other words, if task A (modified at A.t) depends on artefact B (modified at B.t), then
that gives us the dependency list [ A, B, ]

In the dependency chart we enter nodes in the chronological order that is needed for correct computation
with cached intermediate artefacts.

If function `f` depends on some input file `a.json` (which may have changed on disk since the last output
of `f` was written to cache), then we enter the **temporal constraint** `( t 'a.json' ) < ( t 'f' )`
(read: the modification time of the object identified as `'a.json'` must be less than that of `'f'`) as
`L.add g, 'a.json', 'f'`.

'trending', 'the trend'
'drifting', 'the drift'
'the course'
'the chart'

dependency list vs timeline
chart vs trend
?chart vs drift

series
boxed series
indexed series

fault: a mismatch between the ordering relations between a reference entry and a comparison entry as
  displayed in the chart on the one hand and in the trend on the other hand.

* [ ] use URLs like `file:///home/url.json`, `cache://foo`







