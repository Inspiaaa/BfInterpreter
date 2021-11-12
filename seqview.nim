
type SeqView*[T] = object
    data*: ref seq[T]
    bounds*: Slice[int]


proc initSeqView*[T](s: seq[T], bounds: Slice): SeqView[T] =
    var refSeq: ref seq[T]
    new(refSeq)
    shallowCopy(refSeq[], s)
    return SeqView[T](data: refSeq, bounds: bounds)


proc moveTo*[T](self: var SeqView[T], newBounds: Slice) =
    self.bounds = newBounds


proc `[]`*[T](self: SeqView[T], idx: int): T =
    if (idx+self.bounds.a) in self.bounds:
        return self.data[idx + self.bounds.a]
    # Otherwise it returns the default value

proc `[]`*[T](self: SeqView[T], bounds: Slice): SeqView[T] =
    SeqView[T](
        data: self.data,
        bounds: (bounds.a + self.bounds.a)..(bounds.b + self.bounds.b)
    )


iterator items*[T](self: SeqView[T]): T =
    for idx in self.bounds:
        yield self.data[idx]


proc len*[T](self: SeqView[T]): int =
    return self.bounds.b - self.bounds.a
