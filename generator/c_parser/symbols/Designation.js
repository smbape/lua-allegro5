class Designation {
    constructor({
        designators,
        equals
    }, loc) {
        this.designators = designators;
        this.equals = equals;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const designator of this.designators) {
            designator.visit(cb, parents);
        }

        this.equals.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.Designation = Designation;
