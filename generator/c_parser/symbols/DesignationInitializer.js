class DesignationInitializer {
    constructor({
        designation,
        initializer
    }, loc) {
        this.designation = designation;
        this.initializer = initializer;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.designation.visit(cb, parents);
        this.initializer.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.DesignationInitializer = DesignationInitializer;
