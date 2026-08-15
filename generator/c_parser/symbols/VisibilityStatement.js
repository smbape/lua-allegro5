class VisibilityStatement {
    constructor({
        identifier,
        colon
    }, loc) {
        this.identifier = identifier;
        this.colon = colon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.colon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.VisibilityStatement = VisibilityStatement;
